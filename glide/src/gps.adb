with Glib; use Glib;
with Gdk.Window; use Gdk.Window;
with Gtk; use Gtk;
with Gtk.Main;
with Glide_Page;
with Glide_Menu;
with GVD.Main_Window;

procedure Glide2 is
   use GVD.Main_Window;

   Border        : constant := 32;
   Glide         : GVD_Main_Window;
   Page          : Glide_Page.Glide_Page;
   X, Y          : Gint;
   Width, Height : Gint;
   Depth         : Gint;

begin
   Gtk.Main.Set_Locale;
   Gtk.Main.Init;

   Get_Geometry (null, X, Y, Width, Height, Depth);
   Gtk_New (Glide, "<glide>", Glide_Menu.Glide_Menu_Items.all);
   Set_Default_Size (Glide, Width, Height - Border);
   Set_Title (Glide, "Glide - New Generation");
   Glide.Gvd_Home_Dir := new String' ("");
   Glide.Prefix_Directory := new String' ("");

   Glide_Page.Gtk_New (Page, Glide);
   Show_All (Glide);
   Gtk.Main.Main;
end Glide2;
