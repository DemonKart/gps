-----------------------------------------------------------------------
--                   GVD - The GNU Visual Debugger                   --
--                                                                   --
--                      Copyright (C) 2000-2001                      --
--                              ACT-Europe                           --
--                                                                   --
-- GVD is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Glib;
with Gtk.Window; use Gtk.Window;
with Gtk.Widget; use Gtk.Widget;
with GVD.Preferences_Dialog; use GVD.Preferences_Dialog;
with GVD.Open_Program_Dialog; use GVD.Open_Program_Dialog;
with Open_Session_Pkg; use Open_Session_Pkg;
with GVD.Dialogs; use GVD.Dialogs;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with Basic_Types;
with GVD.Types;
with GVD.Histories;
pragma Elaborate_All (GVD.Histories);
with GVD.Memory_View;
with Main_Debug_Window_Pkg; use Main_Debug_Window_Pkg;

package GVD.Main_Window is

   type History_Data is record
      Mode         : GVD.Types.Command_Type;
      Debugger_Num : Natural;
      Command      : String_Access;
   end record;

   type Debugger_List_Node;
   type Debugger_List_Link is access Debugger_List_Node;

   type Debugger_List_Node is record
      Debugger : Gtk_Widget;
      Next     : Debugger_List_Link;
   end record;

   package String_History is new GVD.Histories (History_Data);
   use String_History;

   type GVD_Main_Window_Record is new Main_Debug_Window_Record with record
      Memory_View         : GVD.Memory_View.GVD_Memory_View;
      GVD_Preferences     : GVD_Preferences_Access;
      Open_Program        : GVD_Open_Program;
      Open_Session        : Open_Session_Access;
      History_Dialog      : History_Dialog_Access;
      Thread_Dialog       : Thread_Dialog_Access;
      Task_Dialog         : Task_Dialog_Access;
      Breakpoints_Editor  : Gtk.Window.Gtk_Window;
      Log_File            : File_Descriptor := Standerr;
      TTY_Mode            : Boolean := False;
      Debug_Mode          : Boolean := False;
      Log_Level           : GVD.Types.Command_Type := GVD.Types.Internal;
      External_Editor     : String_Access;
      Prefix_Directory    : String_Access;
      External_XID        : Glib.Guint32 := 0;

      File_Caches         : Basic_Types.File_Cache_List;
      --  List of data cached for each of the file of the application
      --  This field is handled in GVD.Files

      Command_History : String_History.History_List;
      --  The history of commands for the current session.

      Sessions_Dir        : String_Access;
      --  The directory containing session files.

      Gvd_Home_Dir        : String_Access;
      --  The location of the ~/.gvd directory.
      --  The preferences file is found in Gvd_Home_Dir/preferences

      First_Debugger      : Debugger_List_Link;
      --  The pointer to the list of debuggers.

      Locked              : Boolean := False;
      --  Boolean used to handle global locking between debugger pages.
   end record;
   type GVD_Main_Window is access all GVD_Main_Window_Record'Class;

   procedure Gtk_New (Main_Window : out GVD_Main_Window);
   procedure Initialize (Main_Window : access GVD_Main_Window_Record'Class);

   procedure Update_External_Dialogs
     (Window   : access GVD_Main_Window_Record'Class;
      Debugger : Gtk.Widget.Gtk_Widget := null);
   --  Update the contents of all the dialogs associated with the window
   --  (backtrace, threads, ...) if they are visible.
   --  Their contents is updated based on the current debugger, unless
   --  Debugger is not null.

   procedure Find_Match
     (H   : in out History_List;
      Num : in Natural;
      D   : in Direction);
   --  Moves in the history in the given direction until it finds a non-hidden
   --  command which was sent to the debugger with number Num.
   --  No_Such_Item is raised if no matching command is found.

   procedure Preferences_Changed
     (Window : access GVD_Main_Window_Record'Class);
   --  Emit the "preferences_changed" signal, which indicates a change in
   --  the preferences. The exact change is not accessible as a parameter.

   procedure Cleanup_Debuggers (Window : access GVD_Main_Window_Record'Class);
   --  Close all the debuggers associated with a given main debug window
   --  by looking at all the pages of the main notebook.

end GVD.Main_Window;
