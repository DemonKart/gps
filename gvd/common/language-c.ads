-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
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

--  This is the general C (non debugger specific) support package.
--  See language.ads and language-debugger.ads for a complete spec.

package Language.Debugger.C is

   type C_Language is new Language_Debugger with private;

   -------------
   -- Parsing --
   -------------

   function Is_Simple_Type
     (Lang : access C_Language; Str : String) return Boolean;

   ------------------
   -- Highlighting --
   ------------------

   function Keywords (Lang : access C_Language)
                     return GNAT.Regpat.Pattern_Matcher;

   function Get_Language_Context
     (Lang : access C_Language) return Language_Context;

   ---------------------------------
   -- Language specific functions --
   ---------------------------------

   function Start (Debugger  : access C_Language) return String;

   --------------
   -- Explorer --
   --------------

   function Explorer_Regexps
     (Lang : access C_Language) return Explorer_Categories;

   ------------------------
   -- Naming Conventions --
   ------------------------

   function Dereference_Name
     (Lang : access C_Language;
      Name : String) return String;

   function Array_Item_Name
     (Lang  : access C_Language;
      Name  : String;
      Index : String) return String;

   function Record_Field_Name
     (Lang  : access C_Language;
      Name  : String;
      Field : String) return String;

private
   type C_Language is new Language_Debugger with null record;
end Language.Debugger.C;
