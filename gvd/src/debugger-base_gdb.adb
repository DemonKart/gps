------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2017, AdaCore                          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Characters.Handling;  use Ada.Characters.Handling;
with Ada.Tags;                 use Ada.Tags;
with GNAT.Strings;             use GNAT.Strings;
with GNATCOLL.Utils;           use GNATCOLL.Utils;

with Items.Arrays;             use Items.Arrays;
with Items.Classes;            use Items.Classes;
with Items.Records;            use Items.Records;
with Items.Simples;            use Items.Simples;
with Items;                    use Items;
with Language.Debugger;        use Language.Debugger;
with Language;                 use Language;
with String_Utils;             use String_Utils;
with GPS.Kernel.Hooks;         use GPS.Kernel.Hooks;
with GPS.Intl;                 use GPS.Intl;

with GVD.Dialogs;              use GVD.Dialogs;
with GVD.Trace;                use GVD.Trace;

with Debugger.Base_Gdb.Ada;    use Debugger.Base_Gdb.Ada;
with Debugger.Base_Gdb.C;      use Debugger.Base_Gdb.C;
with Debugger.Base_Gdb.Cpp;    use Debugger.Base_Gdb.Cpp;

package body Debugger.Base_Gdb is

   No_Definition_Of : constant String := "No definition of";
   --  Another string used to detect undefined commands

   --------------------------
   -- Detect_Debugger_Mode --
   --------------------------

   procedure Detect_Debugger_Mode (Debugger : access Base_Gdb_Debugger) is
   begin
      if Debugger.Remote_Protocol = null
        or else Debugger.Remote_Protocol.all = ""
      then
         Debugger.Remote_Mode := Native;

      elsif To_Lower (Debugger.Remote_Protocol.all) = "wtx"
        or else To_Lower (Debugger.Remote_Protocol.all) = "dfw"
        or else To_Lower (Debugger.Remote_Protocol.all) = "dfw-rtp"
        or else To_Lower (Debugger.Remote_Protocol.all) = "vxworks"
      then
         Debugger.Remote_Mode := VxWorks;

      else
         Debugger.Remote_Mode := Cross;
      end if;
   end Detect_Debugger_Mode;

   --------------------------
   -- Internal_Parse_Value --
   --------------------------

   procedure Internal_Parse_Value
     (Lang       : access Language.Debugger.Language_Debugger'Class;
      Type_Str   : String;
      Index      : in out Natural;
      Result     : in out Items.Generic_Type_Access;
      Repeat_Num : out Positive;
      Parent     : Items.Generic_Type_Access)
   is
      procedure Skip_Parenthesis (Index : in out Natural);
      --  Skip the parenthesis pair starting at Index, taking into account
      --  nested parenthesis

      ----------------------
      -- Skip_Parenthesis --
      ----------------------

      procedure Skip_Parenthesis (Index : in out Natural) is
         Num : Natural := 1;
      begin
         if Index <= Type_Str'Last and then Type_Str (Index) = '(' then
            Index := Index + 1;
            while Num /= 0
              and then Index <= Type_Str'Last
            loop
               if Type_Str (Index) = ')' then
                  Num := Num - 1;
               elsif Type_Str (Index) = '(' then
                  Num := Num + 1;
               end if;
               Index := Index + 1;
            end loop;
            Index := Index + 1;
         end if;
      end Skip_Parenthesis;

      Context : constant Language_Debugger_Context :=
                  Get_Language_Debugger_Context (Lang);
      Dim     : Dimension;

   begin
      Repeat_Num := 1;

      if Looking_At (Type_Str, Index, "Cannot access memory at address") then
         while Index <= Type_Str'Last loop
            exit when Type_Str (Index) = ','
              or else Type_Str (Index) = ')'
              or else Type_Str (Index) = '}'
              or else Type_Str (Index) = '>';
            Index := Index + 1;
         end loop;

         if Result'Tag = Simple_Type'Tag
           or else Result'Tag = Range_Type'Tag
           or else Result'Tag = Mod_Type'Tag
           or else Result'Tag = Enum_Type'Tag
         then
            Set_Value (Simple_Type (Result.all), "<???>");

         elsif Result'Tag = Access_Type'Tag then
            Set_Value (Simple_Type (Result.all), "0x0");
         end if;

         return;
      end if;

      -------------------
      -- Simple values --
      -------------------

      if Result'Tag = Simple_Type'Tag
        or else Result'Tag = Range_Type'Tag
        or else Result'Tag = Mod_Type'Tag
        or else Result'Tag = Enum_Type'Tag
      then
         if Type_Str /= "" then
            Skip_Parenthesis (Index);
            declare
               Int : constant Natural := Index;
            begin
               Skip_Simple_Value (Type_Str, Index,
                                  Array_Item_Separator => ',',
                                  End_Of_Array         => Context.Array_End,
                                  Repeat_Item_Start    => '<');
               Set_Value (Simple_Type (Result.all),
                          Type_Str (Int .. Index - 1));
            end;
         else
            Set_Value (Simple_Type (Result.all), "<???>");
         end if;

      -------------------
      -- Access values --
      -------------------
      --  The value looks like:   (access integer) 0xbffff54c
      --  or                  :    0x0
      --  or                  :   (<ref> TstringS29b) @0xbfffdba0
      --  or                  :   (void (*)()) 0x804845c <foo>

      elsif Result'Tag = Access_Type'Tag then

         if Looking_At (Type_Str, Index, "(null)") then
            Set_Value (Simple_Type (Result.all), "0x0");
            Index := Index + 6;

         else
            Skip_Parenthesis (Index);

            --  Access to subprograms are sometimes printed as:
            --     {void ()} 0x402488e4 <gtk_window_destroy>
            if Index <= Type_Str'Last and then Type_Str (Index) = '{' then
               Skip_To_Char (Type_Str, Index, '}');
               Index := Index + 2;
            end if;

            if Index <= Type_Str'Last and then Type_Str (Index) = '@' then
               Index := Index + 1;
            end if;

            declare
               Int : constant Natural := Index;
            begin
               Skip_Hexa_Digit (Type_Str, Index);

               --  If we have an extra indication like
               --      <gtk_window_finalize>
               --  in the value, keep it.

               if Index < Type_Str'Last - 2
                 and then Type_Str (Index + 1) = '<'
                 and then not Looking_At (Type_Str, Index + 2, "repeats ")
               then
                  Skip_To_Char (Type_Str, Index, '>');
                  Index := Index + 1;

                  --  Also keep string indications (for char* in C)
               elsif Index < Type_Str'Last - 2
                 and then (Type_Str (Index + 1) = '"'
                           or else Type_Str (Index + 1) = ''')
               then
                  declare
                     Str      : String (1 .. 0);
                     Str_Last : Natural;
                  begin
                     Index := Index + 1;
                     Parse_Cst_String
                       (Type_Str, Index, Str, Str_Last,
                        Backslash_Special => Get_Language_Context
                          (Lang).Quote_Character = '\');
                     Index := Index - 1;
                  end;
               end if;

               Set_Value
                 (Simple_Type (Result.all), Type_Str (Int .. Index - 1));
            end;
         end if;

      -------------------
      -- String values --
      -------------------

      elsif Result'Tag = Array_Type'Tag
        and then Num_Dimensions (Array_Type (Result.all)) = 1
        and then Type_Str'Length /= 0
        and then
          (Type_Str (Index) = '"'
           or else Type_Str (Index) = ''')
      then
         Dim := Get_Dimensions (Array_Type (Result.all), 1);

         --  If the dimension was not known when parsing the type, we compute
         --  it directly from the value of the string

         if Dim.Last < Dim.First then
            declare
               Tmp : Natural := Index;
               S   : String (1 .. 0);
               S_Last : Natural;
            begin
               Parse_Cst_String (Type_Str, Tmp, S, S_Last);
               Dim.Last := Long_Integer (Tmp - Index) + Dim.First - 4;
            end;
         end if;

         declare
            S : String (1 .. Integer (Dim.Last - Dim.First + 1));
            S_Last : Natural;
            Simple : Simple_Type_Access;

         begin
            Parse_Cst_String
              (Type_Str, Index, S, S_Last,
               Backslash_Special => Get_Language_Context
               (Lang).Quote_Character = '\');
            Simple := Simple_Type_Access
              (Get_Value (Array_Type (Result.all), Dim.First));

            if Simple = null then
               Simple := Simple_Type_Access (New_Simple_Type);
            end if;

            Set_Value (Simple.all, S (S'First .. S_Last));

            --  The index should always be 0, since we add Dim.First before
            --  displaying it.

            Set_Value (Item       => Array_Type (Result.all),
                       Elem_Value => Simple,
                       Elem_Index => 0);
            Shrink_Values (Array_Type (Result.all));
         end;

      ------------------
      -- Array values --
      ------------------

      elsif Result'Tag = Array_Type'Tag
        and then Type_Str'Length /= 0   --  for empty Arrays
        and then Type_Str /= "[0]"
      then
         --  Some array types can in fact be transformed into access types.
         --  This is the case for instance in C for empty arrays ("int[0]" can
         --  have a value of "0x..."), or in Ada for unconstrained arrays
         --  ("array (1..1) of string" can have a value of "(0x0").
         --  For such cases, we change the type once and for all, since we will
         --  never need to go back to an array type.
         --  See also "(<ref> TstringS29b) @0xbfffdba0: Index bound unknown.",
         --  which starts with the right character but is in fact an array
         --  type.
         --  There is also
         --  "(<ref> array (...) of string) @0xbffff5fc: ((null), (null))"
         --  where the value of the array is indeed visible, in which case we
         --  try and keep the array as long as possible

         if Index + 11 < Type_Str'Last
           and then Type_Str (Index + 1 .. Index + 11) = "<ref> array"
         then
            declare
               Num_Open : Integer := 0;
            begin
               Index := Index + 12;

               while Num_Open /= -1 loop
                  if Type_Str (Index) = '(' then
                     Num_Open := Num_Open + 1;
                  elsif Type_Str (Index) = ')' then
                     Num_Open := Num_Open - 1;
                  end if;

                  Index := Index + 1;
               end loop;
            end;

            Skip_To_Char (Type_Str, Index, ':');
            Index := Index + 2;
            Internal_Parse_Value
              (Lang, Type_Str, Index, Result, Repeat_Num, Parent);

         elsif Type_Str (Index) /= Context.Array_Start
           or else (Index + 5 <= Type_Str'Last
                    and then Type_Str (Index + 1 .. Index + 5) = "<ref>")
         then
            --  If we have "(<ref> array (...) of string) @0xbffff5fc: ((null),
            --  (null))", this is still considered as an array, which is
            --  friendlier for the user in the canvas.

            declare
               Tmp : Natural := Index;
            begin
               Skip_To_Char (Type_Str, Tmp, ')');
               Skip_To_Char (Type_Str, Tmp, ':');

               if Tmp < Type_Str'Last
                 and then Type_Str (Tmp .. Tmp + 1) = " ("
               then
                  Index := Tmp;
                  Parse_Array_Value
                    (Lang, Type_Str, Index, Array_Type_Access (Result));
                  return;
               end if;
            end;

            --  Otherwise, we convert to an access type

            if Parent /= null then
               Result := Replace (Parent, Result, New_Access_Type);
            else
               Free (Result, Only_Value => False);
               Result := New_Access_Type;
            end if;

            Internal_Parse_Value
              (Lang, Type_Str, Index, Result, Repeat_Num, Parent => Parent);

         else
            Parse_Array_Value
              (Lang, Type_Str, Index, Array_Type_Access (Result));
         end if;

      -------------------
      -- Record values --
      -------------------

      elsif Result'Tag = Record_Type'Tag
        or else Result'Tag = Union_Type'Tag
      then
         declare
            R   : constant Record_Type_Access := Record_Type_Access (Result);
            Int : Natural;
         begin
            --  Skip initial '(' if we are still looking at it (we might not
            --  if we are parsing a variant part)

            if Index <= Type_Str'Last
              and then Type_Str (Index) = Context.Record_Start
            then
               Index := Index + 1;
            end if;

            for J in 1 .. Num_Fields (R.all) loop

               exit when Index >= Type_Str'Last;

               --  If we are expecting a field

               if Get_Variant_Parts (R.all, J) = 0 then
                  declare
                     V          : Generic_Type_Access := Get_Value (R.all, J);
                     Repeat_Num : Positive;
                  begin
                     --  Skips '=>'
                     --  This also skips the address part in some "in out"
                     --  parameters, like:
                     --    (<ref> gnat.expect.process_descriptor) @0x818a990: (
                     --     pid => 2012, ...

                     Skip_To_String (Type_Str, Index, Context.Record_Field);
                     Index := Index + 1 + Context.Record_Field_Length;
                     Internal_Parse_Value
                       (Lang, Type_Str, Index, V, Repeat_Num,
                        Parent => Result);
                  end;

               --  Else we have a variant part record

               else
                  if Type_Str (Index) = ',' then
                     Index := Index + 1;
                     Skip_Blanks (Type_Str, Index);
                  end if;

                  --  Find which part is active
                  --  We simply get the next field name and search for the
                  --  part that defines it. Note that in case with have a
                  --  'null' part, we have to stop at the closing parens.

                  Int := Index;
                  while Int <= Type_Str'Last
                    and then Type_Str (Int) /= ' '
                    and then Type_Str (Int) /= ')'
                  loop
                     Int := Int + 1;
                  end loop;

                  --  Reset the valid flag, so that only one of the variant
                  --  parts is valid.

                  declare
                     Repeat_Num : Positive;
                     V : Generic_Type_Access;
                  begin
                     V := Find_Variant_Part
                       (Item     => R.all,
                        Field    => J,
                        Contains => Type_Str (Index .. Int - 1));

                     --  Variant part not found. This happens for instance when
                     --  gdb doesn't report the "when others" part of a variant
                     --  record in the type if it has a no field, as in
                     --       type Essai (Discr : Integer := 1) is record
                     --         case Discr is
                     --             when 1 => Field1 : Integer;
                     --             when others => null;
                     --         end case;
                     --       end record;
                     --  ptype reports
                     --    type = record
                     --       discr : integer;
                     --       case discr is
                     --           when 1 => field1 : integer;
                     --       end case;
                     --    end record;

                     if V /= null then
                        Internal_Parse_Value
                          (Lang, Type_Str, Index, V, Repeat_Num,
                           Parent => Result);
                     end if;
                  end;
               end if;
            end loop;
         end;

         Skip_Blanks (Type_Str, Index);

         --  Skip closing ')', if seen
         if Index <= Type_Str'Last
           and then Type_Str (Index) = Context.Record_End
         then
            Index := Index + 1;
         end if;

      ------------------
      -- Class values --
      ------------------

      elsif Result'Tag = Class_Type'Tag then
         declare
            R : Generic_Type_Access;
         begin
            for A in 1 .. Get_Num_Ancestors (Class_Type (Result.all)) loop
               R := Get_Ancestor (Class_Type (Result.all), A);
               Internal_Parse_Value
                 (Lang, Type_Str, Index, R, Repeat_Num, Parent => Result);
            end loop;
            R := Get_Child (Class_Type (Result.all));

            if Num_Fields (Record_Type (R.all)) /= 0 then
               Internal_Parse_Value
                 (Lang, Type_Str, Index, R, Repeat_Num, Parent => Result);
            end if;
         end;
      end if;

      -------------------
      -- Repeat values --
      -------------------
      --  This only happens inside arrays, so we can simply replace
      --  Result

      Skip_Blanks (Type_Str, Index);
      if Looking_At (Type_Str, Index, "<repeats ") then
         Index := Index + 9;
         Parse_Num (Type_Str,
                    Index,
                    Long_Integer (Repeat_Num));
         Index := Index + 7;  --  skips " times>"
      end if;
   end Internal_Parse_Value;

   -----------------------------
   -- Prepare_Target_For_Send --
   -----------------------------

   procedure Prepare_Target_For_Send
     (Debugger : access Base_Gdb_Debugger;
      Cmd      : String)
   is
      J, K : Integer;
   begin
      if Cmd'Length > 10
        and then Cmd (Cmd'First .. Cmd'First + 6) = "target "
      then
         J := Cmd'First + 7;
         Skip_Blanks (Cmd, J);
         K := J + 1;
         Skip_To_Blank (Cmd, K);

         if K < Cmd'Last then
            Free (Debugger.Remote_Protocol);
            Debugger.Remote_Protocol := new String'(Cmd (J .. K - 1));
            Debugger.Detect_Debugger_Mode;

            J := K + 1;
            Skip_Blanks (Cmd, J);
            Free (Debugger.Remote_Target);
            Debugger.Remote_Target := new String'(Cmd (J .. Cmd'Last));
         end if;
      end if;
   end Prepare_Target_For_Send;

   -------------------------
   -- Test_If_Has_Command --
   -------------------------

   procedure Test_If_Has_Command
     (Debugger : access Base_Gdb_Debugger;
      Flag     : in out GNATCOLL.Tribooleans.Triboolean;
      Command  : String)
   is
      use GNATCOLL.Tribooleans;
   begin
      if Flag = Indeterminate then
         declare
            S : constant String := Debugger_Root'Class
              (Debugger.all).Send_And_Get_Clean_Output
              ("help " & Command, Mode => GVD.Types.Internal);
         begin
            if Starts_With (S, Undefined_Command)
              or else Starts_With (S, No_Definition_Of)
            then
               Flag := False;
            else
               Flag := True;
            end if;
         end;
      end if;
   end Test_If_Has_Command;

   ----------------------
   -- Question_Filter1 --
   ----------------------

   procedure Question_Filter1
     (Process : access Visual_Debugger_Record'Class;
      Str     : String;
      Matched : Match_Array)
   is
      use GVD.Types;

      Dialog   : Question_Dialog_Access;
      Index    : Natural;
      Debugger : constant Debugger_Access := Process.Debugger;
      Choices  : Question_Array (1 .. 1000);
      --  ??? This is an arbitrary hard-coded limit, that should
      --  be enough. Might be nice to remove it though.

      Num   : Natural := 0;
      First : Positive;
      Last  : Positive := Matched (0).First;

   begin
      if Base_Gdb_Debugger'Class (Debugger.all).Initializing then
         --  Debugger has not been fully initialized yet, ignore
         return;
      end if;

      --  Always call the hook, even in invisible mode. This is in particular
      --  useful for the automatic testsuite

      declare
         Result : constant String := Debugger_Question_Action_Hook.Run
            (Process.Kernel, Process, Str);
      begin
         if Result /= "" then
            Debugger.Send
              (Result,
               Mode            => Internal,
               Empty_Buffer    => False,
               Force_Send      => True,
               Wait_For_Prompt => False);
            return;
         end if;
      end;

      --  ??? An issue occurs if the hook returned True, but in fact no reply
      --  was sent to the debugger. In this case, the debugger stays blocked
      --  waiting for input. Since this is visible in the console, that means
      --  the user will have to type (though it still fails in automatic tests,
      --  since commands are sent in invisible mode)

      --  If we are processing an internal command, we cancel any question
      --  dialog we might have, and silently fail
      --  ??? For some reason, we can not use Interrupt here, and we have
      --  to rely on the fact that "Cancel" is the first choice.

      if Debugger.Get_Process.Get_Command_Mode = Internal then
         Debugger.Send
           ("0",
            Mode            => Internal,
            Empty_Buffer    => False,
            Force_Send      => True,
            Wait_For_Prompt => False);
         return;

      --  For a hidden command, we also cannot afford to wait, so send an
      --  answer. 1 will typically map to "all".

      elsif Debugger.Get_Process.Get_Command_Mode = Hidden then
         Debugger.Send
           ("1",
            Mode            => Hidden,
            Empty_Buffer    => False,
            Force_Send      => True,
            Wait_For_Prompt => False);
         return;
      end if;

      --  Index is positioned to the last LF character: "[0] ...\n> "

      Index := Matched (0).Last - 2;

      while Last < Index loop
         --  Skips the choice number ("[n] ")
         Skip_To_Char (Str, Last, ']');
         Last  := Last + 1;
         while Str (Last) = ' ' loop
            Last := Last + 1;
         end loop;

         First := Last;

         while Last < Index
           and then Str (Last) /= ASCII.LF
           and then Str (Last) /= '\'
         loop
            Last := Last + 1;
         end loop;

         Num := Num + 1;
         Choices (Num).Choice :=
           new String'(Natural'Image (Num - 1));
         Choices (Num).Description :=
           new String'(Str (First .. Last - 1));

         Skip_To_Char (Str, Last, '[');
      end loop;

      Gtk_New
        (Dialog,
         Process.Kernel,
         Debugger,
         True,
         Choices (1 .. Num));
      Dialog.Show_All;

      for J in 1 .. Num loop
         Free (Choices (Num).Choice);
         Free (Choices (Num).Description);
      end loop;
   end Question_Filter1;

   ----------------------
   -- Question_Filter2 --
   ----------------------

   procedure Question_Filter2
     (Process : access Visual_Debugger_Record'Class;
      Str     : String;
      Matched : Match_Array)
   is
      use GVD.Types;

      Dialog   : Question_Dialog_Access;
      Debugger : constant Debugger_Access := Process.Debugger;
      Choices  : Question_Array (1 .. 2);
      Mode     : Command_Type;

   begin
      if Base_Gdb_Debugger'Class (Debugger.all).Initializing then
         --  Debugger has not been fully initialized yet, ignore
         return;
      end if;

      --  Always call the hook, even in invisible mode. This is in particular
      --  useful for the automatic testsuite

      declare
         Output : constant String := Debugger_Question_Action_Hook.Run
           (Process.Kernel, Process, Str);
      begin
         if Output /= "" then
            Send (Debugger, Output,
                  Mode            => Internal,
                  Empty_Buffer    => False,
                  Force_Send      => True,
                  Wait_For_Prompt => False);
            return;
         end if;
      end;

      Mode := Debugger.Get_Process.Get_Command_Mode;

      --  For an invisible command, we cannot afford to wait, so send an
      --  answer automatically.

      if Mode in Invisible_Command then
         Debugger.Send
           ("y",
            Mode            => Mode,
            Empty_Buffer    => False,
            Force_Send      => True,
            Wait_For_Prompt => False);
         return;
      end if;

      --  Should we display the dialog or not ?

      Choices (1).Choice := new String'("n");
      Choices (1).Description := new String'("No");

      Choices (2).Choice := new String'("y");
      Choices (2).Description := new String'("Yes");

      Gtk_New
        (Dialog,
         Process.Kernel,
         Debugger,
         False,
         Choices,
         Str (Matched (0).First .. Matched (0).Last));
      Dialog.Show_All;

      for J in Choices'Range loop
         Free (Choices (J).Choice);
         Free (Choices (J).Description);
      end loop;
   end Question_Filter2;

   ---------------------
   -- Language_Filter --
   ---------------------

   procedure Language_Filter
     (Process : access Visual_Debugger_Record'Class;
      Str     : String;
      Matched : Match_Array)
   is
      Debugger : constant Debugger_Access := Process.Debugger;
      Lang     : constant String :=
        Str (Matched (3).First .. Matched (3).Last);
      Language : Language_Access;

   begin
      --  Is this a language we have seen before ? If yes, reuse it in case
      --  it needs to dynamically query the debugger to find out if a
      --  feature is supported, to avoid doing it every time we switch to
      --  that language

      Language := Debugger.Get_Language (Lang);

      if Language = null then
         if Lang = "ada" then
            Language := new Gdb_Ada_Language;
         elsif Lang = "c" then
            Language := new Gdb_C_Language;
         elsif Lang = "c++" then
            Language := new Gdb_Cpp_Language;
         elsif Lang = "auto" then
            --  Do not change the current language if gdb isn't able to
            --  tell what the new language is
            return;
         else
            Output_Error
              (Process.Kernel,
               (-"Language unknown, defaulting to C: ") & Lang);

            --  We need to check whether we already have C defined:
            Language := Debugger.Get_Language ("c");
            if Language = null then
               Language := new Gdb_C_Language;
            end if;
         end if;

         Set_Debugger
           (Language_Debugger_Access (Language), Debugger.all'Access);
      end if;

      Debugger.Set_Language (Language);
   end Language_Filter;

end Debugger.Base_Gdb;
