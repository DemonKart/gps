-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2004                            --
--                            ACT-Europe                             --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Glib;                        use Glib;
with Glib.Object;                 use Glib.Object;
with Glib.Properties.Creation;    use Glib.Properties.Creation;
with Glib.Xml_Int;                use Glib.Xml_Int;
with Glide_Kernel;                use Glide_Kernel;
with Glide_Kernel.Contexts;       use Glide_Kernel.Contexts;
with Glide_Kernel.Modules;        use Glide_Kernel.Modules;
with Glide_Kernel.Standard_Hooks; use Glide_Kernel.Standard_Hooks;
with Glide_Kernel.Preferences;    use Glide_Kernel.Preferences;
with Glide_Kernel.Hooks;          use Glide_Kernel.Hooks;
with GUI_Utils;                   use GUI_Utils;
with VFS;                         use VFS;
with Pixmaps_IDE;                 use Pixmaps_IDE;
with Gdk.Pixbuf;                  use Gdk.Pixbuf;
with Gdk.Event;                   use Gdk.Event;
with Gtk.Box;                     use Gtk.Box;
with Gtk.Enums;                   use Gtk.Enums;
with Gtk.Menu;                    use Gtk.Menu;
with Gtk.Tree_Model;              use Gtk.Tree_Model;
with Gtk.Tree_View;               use Gtk.Tree_View;
with Gtk.Tree_Store;              use Gtk.Tree_Store;
with Gtk.Tree_Selection;          use Gtk.Tree_Selection;
with Gtk.Widget;                  use Gtk.Widget;
with Gtkada.Handlers;             use Gtkada.Handlers;
with Gtkada.MDI;                  use Gtkada.MDI;
with Glide_Intl;                  use Glide_Intl;
with Entities;                    use Entities;
with Projects;                    use Projects;
with Language;                    use Language;
with Language_Handlers.Glide;     use Language_Handlers.Glide;
with Basic_Types;                 use Basic_Types;
with Gtk.Scrolled_Window;         use Gtk.Scrolled_Window;
with Project_Explorers_Common;    use Project_Explorers_Common;
--  with Traces;                      use Traces;
with Default_Preferences;         use Default_Preferences;

package body Outline_View is

--   Me : constant Debug_Handle := Create ("Outline_View");

   Outline_View_Module : Module_ID;

   Outline_View_Font                : Param_Spec_Font;
   Outline_View_Profiles            : Param_Spec_Boolean;
   Outline_View_Sort_Alphabetically : Param_Spec_Boolean;

   procedure On_Context_Changed
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : Hooks_Data'Class);
   --  Called when the context has changed

   function Open_Outline
     (Kernel : access Kernel_Handle_Record'Class)
      return MDI_Child;
   --  Open the outline view, or return a handle to it if it already exists.


   procedure On_Open_Outline
     (Widget : access GObject_Record'Class;
      Kernel : Kernel_Handle);
   --  Raise the existing explorer, or open a new one.

   type Outline_View_Record is new Gtk.Box.Gtk_Box_Record with record
      Tree      : Gtk_Tree_View;
      Kernel    : Kernel_Handle;
      File      : VFS.Virtual_File;
      Icon      : Gdk_Pixbuf;
      File_Icon : Gdk_Pixbuf;
   end record;
   type Outline_View_Access is access all Outline_View_Record'Class;

   procedure Gtk_New
     (Outline : out Outline_View_Access;
      Kernel  : access Kernel_Handle_Record'Class);
   --  Create a new outline view

   procedure Refresh
     (Outline : access Outline_View_Record'Class;
      File    : VFS.Virtual_File);
   --  Display the information for File in the outline view

   function Button_Press
     (Outline : access Gtk_Widget_Record'Class;
      Event   : Gdk_Event) return Boolean;
   --  Called every time a row is clicked

   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
      return Node_Ptr;
   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child;
   --  Handling of desktops

   function Filter_Category
     (Category : Language.Language_Category) return Language.Language_Category;
   --  Return Cat_Unknown if the category should be filtered out, and the
   --  name of the category to use otherwise.

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget) return Selection_Context_Access;
   --  Create the current context

   function Outline_Context_Factory
     (Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu) return Selection_Context_Access;
   --  Context factory when creating contextual menus

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class);
   --  Called when the preferences have changed.

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Child : constant MDI_Child := Find_MDI_Child_By_Tag
        (Get_MDI (Kernel), Outline_View_Record'Tag);
      Outline : Outline_View_Access;
      Sort_Column : Gint;
      pragma Unreferenced (Sort_Column);
   begin
      if Child /= null then
         Outline := Outline_View_Access (Get_Widget (Child));

         Modify_Font (Outline.Tree, Get_Pref (Kernel, Outline_View_Font));

         if Get_Pref (Kernel, Outline_View_Sort_Alphabetically) then
            Thaw_Sort (Gtk_Tree_Store (Get_Model (Outline.Tree)), 1);
         else
            Sort_Column :=
              Freeze_Sort (Gtk_Tree_Store (Get_Model (Outline.Tree)));
         end if;

         Refresh (Outline, Outline.File);
      end if;
   end Preferences_Changed;

   ---------------------
   -- Default_Factory --
   ---------------------

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget) return Selection_Context_Access
   is
      Outline : constant Outline_View_Access := Outline_View_Access (Child);
   begin
      return Outline_Context_Factory
        (Kernel       => Kernel,
         Event_Widget => Outline.Tree,
         Object       => Outline,
         Event        => null,
         Menu         => null);
   end Default_Factory;

   -----------------------------
   -- Outline_Context_Factory --
   -----------------------------

   function Outline_Context_Factory
     (Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu) return Selection_Context_Access
   is
      pragma Unreferenced (Kernel, Event_Widget, Menu);
      Context : Entity_Selection_Context_Access;
      Iter    : Gtk_Tree_Iter;
      Outline : constant Outline_View_Access := Outline_View_Access (Object);
      Model : constant Gtk_Tree_Store :=
        Gtk_Tree_Store (Get_Model (Outline.Tree));
      Path      : Gtk_Tree_Path;
   begin
      Iter := Find_Iter_For_Event (Outline.Tree, Model, Event);

      if Iter /= Null_Iter then
         Path := Get_Path (Model, Iter);
         if not Path_Is_Selected (Get_Selection (Outline.Tree), Path) then
            Set_Cursor (Outline.Tree, Path, null, False);
         end if;
         Path_Free (Path);

         Context := new Entity_Selection_Context;
         Set_Entity_Information
           (Context       => Context,
            Entity_Name   => Get_String (Model, Iter, 5),
            Entity_Column => Integer (Get_Int (Model, Iter, 2)));
         Set_File_Information
           (Context => Context,
            Project => Projects.No_Project,
            File    => Outline.File,
            Line    => Integer (Get_Int (Model, Iter, 1)));

         return Selection_Context_Access (Context);
      else
         return null;
      end if;
   end Outline_Context_Factory;

   ---------------------
   -- Filter_Category --
   ---------------------

   function Filter_Category
     (Category : Language_Category) return Language_Category is
   begin
      --  No "with", "use", "#include"
      --  No constructs ("loop", "if", ...)

      if Category in Dependency_Category
        or else Category in Construct_Category
        or else Category = Cat_Representation_Clause
        or else Category = Cat_Local_Variable
      then
         return Cat_Unknown;

         --  All subprograms are grouped together

      elsif Category in Subprogram_Explorer_Category then
         return Cat_Procedure;

      elsif Category in Type_Category then
         return Cat_Type;

      end if;

      return Category;
   end Filter_Category;

   ------------------
   -- Save_Desktop --
   ------------------

   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
      return Node_Ptr
   is
      N : Node_Ptr;
   begin
      if Widget.all in Outline_View_Record'Class then
         N := new Node;
         N.Tag := new String'("Outline_View");
         return N;
      end if;
      return null;
   end Save_Desktop;

   ------------------
   -- Load_Desktop --
   ------------------

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child
   is
      pragma Unreferenced (MDI);
   begin
      if Node.Tag.all = "Outline_View" then
         return Open_Outline (User);
      end if;
      return null;
   end Load_Desktop;

   ------------------
   -- Button_Press --
   ------------------

   function Button_Press
     (Outline : access Gtk_Widget_Record'Class;
      Event   : Gdk_Event) return Boolean
   is
      View : constant Outline_View_Access := Outline_View_Access (Outline);
      Model : constant Gtk_Tree_Store :=
        Gtk_Tree_Store (Get_Model (View.Tree));
      Iter : Gtk_Tree_Iter;
      Path : Gtk_Tree_Path;
      Line, Column, Column_End : Gint;
   begin
      if Get_Button (Event) = 1 then
         Iter := Find_Iter_For_Event (View.Tree, Model, Event);
         if Iter /= Null_Iter then
            Path := Get_Path (Model, Iter);
            Set_Cursor (View.Tree, Path, null, False);
            Path_Free (Path);
            Line       := Get_Int (Model, Iter, 2);
            Column     := Get_Int (Model, Iter, 3);
            Column_End := Get_Int (Model, Iter, 4);

            if Line /= -1 then
               Open_File_Editor
                 (View.Kernel,
                  View.File,
                  Line       => Natural (Line),
                  Column     => Natural (Column),
                  Column_End => Natural (Column_End));
            end if;
         end if;
      end if;
      return False;
   end Button_Press;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Outline : out Outline_View_Access;
      Kernel  : access Kernel_Handle_Record'Class)
   is
      Scrolled : Gtk_Scrolled_Window;
      Initial_Sort : Integer := 2;
   begin
      Outline := new Outline_View_Record;
      Outline.Kernel := Kernel_Handle (Kernel);
      Initialize_Vbox (Outline, Homogeneous => False);

      if not Get_Pref (Kernel, Outline_View_Sort_Alphabetically) then
         Initial_Sort := -1;
      end if;

      Gtk_New (Scrolled);
      Pack_Start (Outline, Scrolled, Expand => True);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);

      Outline.Tree := Create_Tree_View
        (Column_Types       => (1 => Gdk.Pixbuf.Get_Type,
                                2 => GType_String,
                                3 => GType_Int,     --  line
                                4 => GType_Int,     --  column
                                5 => GType_Int,     --  column_end
                                6 => GType_String), --  entity name
         Column_Names       => (1 => null, 2 => null),
         Show_Column_Titles => False,
         Initial_Sort_On    => Initial_Sort,
         Selection_Mode     => Gtk.Enums.Selection_None);
      Add (Scrolled, Outline.Tree);

      Outline.Icon := Gdk_New_From_Xpm_Data (var_xpm);
      Outline.File_Icon := Gdk_New_From_Xpm_Data (mini_page_xpm);

      Modify_Font (Outline.Tree, Get_Pref (Kernel, Outline_View_Font));

      Return_Callback.Object_Connect
        (Outline.Tree,
         "button_release_event",
         Return_Callback.To_Marshaller (Button_Press'Access),
         Slot_Object => Outline,
         After       => False);

      Register_Contextual_Menu
        (Kernel          => Kernel,
         Event_On_Widget => Outline.Tree,
         Object          => Outline,
         ID              => Outline_View_Module,
         Context_Func    => Outline_Context_Factory'Access);
   end Gtk_New;

   -------------
   -- Refresh --
   -------------

   procedure Refresh
     (Outline : access Outline_View_Record'Class;
      File    : VFS.Virtual_File)
   is
      Model      : constant Gtk_Tree_Store :=
        Gtk_Tree_Store (Get_Model (Outline.Tree));
      Iter, Root : Gtk_Tree_Iter;
      Lang       : Language_Access;
      Handler    : LI_Handler;
      Languages  : constant Glide_Language_Handler :=
        Glide_Language_Handler (Get_Language_Handler (Outline.Kernel));
      Constructs : Construct_List;
      Show_Profiles : constant Boolean :=
        Get_Pref (Outline.Kernel, Outline_View_Profiles);
      Sort_Column : constant Gint := Freeze_Sort (Model);
   begin
      Push_State (Outline.Kernel, Busy);
      Clear (Model);

      Outline.File := File;

      Handler := Get_LI_Handler_From_File (Languages, File);
      Lang := Get_Language_From_File (Languages, File);

      Append (Model, Root, Null_Iter);
      Set (Model, Root, 0, C_Proxy (Outline.File_Icon));
      Set (Model, Root, 1, "File: " & Base_Name (File));
      Set (Model, Root, 2, -1);

      if Handler = null or Lang = null then
         Append (Model, Iter, Root);
         Set (Model, Iter, 0, C_Proxy (Outline.Icon));
         Set (Model, Iter, 1, "No outline available");
         Set (Model, Iter, 2, -1);
         Set (Model, Iter, 3, -1);
      else
         Parse_File_Constructs
           (Handler, Languages, File, Constructs);
         Constructs.Current := Constructs.First;
         while Constructs.Current /= null loop
            if Constructs.Current.Name /= null then
               if Filter_Category (Constructs.Current.Category) /=
                 Cat_Unknown
               then
                  Append (Model, Iter, Root);
                  Set (Model, Iter, 0, C_Proxy (Outline.Icon));
                  Set (Model, Iter, 1,
                       Entity_Name_Of (Constructs.Current.all,
                                       Show_Profiles => Show_Profiles));
                  Set (Model, Iter, 2,
                       Gint (Constructs.Current.Sloc_Entity.Line));
                  Set (Model, Iter, 3,
                       Gint (Constructs.Current.Sloc_Entity.Column));
                  Set (Model, Iter, 4,
                       Gint (Constructs.Current.Sloc_Entity.Column
                             + Constructs.Current.Name'Length));
                  Set (Model, Iter, 5, Constructs.Current.Name.all);
               end if;
            end if;
            Constructs.Current := Constructs.Current.Next;
         end loop;
      end if;

      Expand_All (Outline.Tree);

      Pop_State (Outline.Kernel);
      Thaw_Sort (Model, Sort_Column);
   end Refresh;

   ---------------------
   -- On_Open_Outline --
   ---------------------

   procedure On_Open_Outline
     (Widget : access GObject_Record'Class;
      Kernel : Kernel_Handle)
   is
      Outline : MDI_Child;
      pragma Unreferenced (Widget);
   begin
      Outline := Open_Outline (Kernel);
      Raise_Child (Outline);
      Set_Focus_Child (Get_MDI (Kernel), Outline);
   end On_Open_Outline;

   ------------------
   -- Open_Outline --
   ------------------

   function Open_Outline
     (Kernel : access Kernel_Handle_Record'Class)
      return MDI_Child
   is
      Child   : MDI_Child;
      Outline : Outline_View_Access;
      Data    : Context_Hooks_Args;
   begin
      Child := Find_MDI_Child_By_Tag
        (Get_MDI (Kernel), Outline_View_Record'Tag);

      if Child = null then
         Data := Context_Hooks_Args'
           (Hooks_Data with Context => Get_Current_Context (Kernel));

         Gtk_New (Outline, Kernel);
         Child := Put
           (Kernel, Outline,
            Default_Width  => 215,
            Default_Height => 600,
            Module         => Outline_View_Module);
         Set_Title (Child, -"Outline View", -"Outline View");
         Set_Dock_Side (Child, Left);
         Dock_Child (Child);

         On_Context_Changed (Kernel, Data);
      end if;

      return Child;
   end Open_Outline;

   ------------------------
   -- On_Context_Changed --
   ------------------------

   procedure On_Context_Changed
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : Hooks_Data'Class)
   is
      D       : constant Context_Hooks_Args := Context_Hooks_Args (Data);
      Outline : Outline_View_Access;
      File    : Virtual_File;
      Child   : MDI_Child;
   begin
      Child := Find_MDI_Child_By_Tag
        (Get_MDI (Kernel), Outline_View_Record'Tag);

      if Child /= null
        and then D.Context.all in File_Selection_Context'Class
        and then Has_File_Information
          (File_Selection_Context_Access (D.Context))
      then
         Outline := Outline_View_Access (Get_Widget (Child));
         File := File_Information
           (File_Selection_Context_Access (D.Context));
         if File /= Outline.File then
            Refresh (Outline, File);
         end if;
      end if;
   end On_Context_Changed;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class)
   is
      Project : constant String := '/' & (-"Project");
      N       : Node_Ptr;
   begin
      Register_Module
        (Module      => Outline_View_Module,
         Module_Name => "Outline_View",
         Default_Context_Factory => Default_Factory'Access,
         Kernel      => Kernel);

      Register_Menu
        (Kernel, Project, -"Outline View", "", On_Open_Outline'Access);
      Add_Hook (Kernel, Context_Changed_Hook, On_Context_Changed'Access);
      Glide_Kernel.Kernel_Desktop.Register_Desktop_Functions
        (Save_Desktop'Access, Load_Desktop'Access);

      N := new Node;
      N.Tag := new String'("Outline_View");
      Add_Default_Desktop_Item
        (Kernel, N,
         10, 10,
         215, 600,
         "Outline View", "Outline_View",
         Docked, Left,
         True, True);

      Outline_View_Font := Param_Spec_Font
        (Gnew_Font
           (Name => "Outline-View-Font",
            Default => Get_Pref (Kernel, Param_Spec_String (Default_Font)),
            Blurb   => -"Font used in the outline view",
            Nick    => -"Outline View font"));
      Register_Property
        (Kernel, Param_Spec (Outline_View_Font), -"Outline");

      Outline_View_Profiles := Param_Spec_Boolean
        (Gnew_Boolean
           (Name    => "Outline-View-Profiles",
            Default => True,
            Blurb   => -("Whether the outline view should display the profiles"
                         & " of the entities"),
            Nick    => -"Show parameter profiles"));
      Register_Property
        (Kernel, Param_Spec (Outline_View_Profiles), -"Outline");

      Outline_View_Sort_Alphabetically := Param_Spec_Boolean
        (Gnew_Boolean
           (Name    => "Outline-View-Sort-Alphabetical",
            Default => True,
            Blurb   => -("If set, the entities are sorted alphabetically,"
                         & " otherwise they appear in the order they are"
                         & " found in the source file"),
            Nick    => -"Sort alphabetically"));
      Register_Property
        (Kernel, Param_Spec (Outline_View_Sort_Alphabetically), -"Outline");

      Add_Hook (Kernel, Preferences_Changed_Hook, Preferences_Changed'Access);
   end Register_Module;

end Outline_View;
