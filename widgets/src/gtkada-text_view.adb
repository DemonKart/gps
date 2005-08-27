-----------------------------------------------------------------------
--              GtkAda - Ada95 binding for Gtk+/Gnome                --
--                                                                   --
--                   Copyright (C) 2005 AdaCore                      --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Gtk.Text_Buffer; use Gtk.Text_Buffer;
with Gtk.Text_View;   use Gtk.Text_View;

package body Gtkada.Text_View is

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (View   : out Gtkada_Text_View;
      Buffer : Gtkada_Text_Buffer := null) is
   begin
      View := new Gtkada_Text_View_Record;
      Initialize (View, Buffer);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (View   : access Gtkada_Text_View_Record'Class;
      Buffer : Gtkada_Text_Buffer) is
   begin
      Gtk.Text_View.Initialize (View, Gtk_Text_Buffer (Buffer));
   end Initialize;

end Gtkada.Text_View;
