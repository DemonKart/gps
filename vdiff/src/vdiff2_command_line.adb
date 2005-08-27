-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2001-2005                       --
--                             AdaCore                               --
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

with GPS.Kernel.Standard_Hooks;         use GPS.Kernel.Standard_Hooks;
with Vdiff2_Module.Utils;               use Vdiff2_Module.Utils;
with Vdiff2_Module.Utils.Shell_Command;
use Vdiff2_Module.Utils.Shell_Command;
with Vdiff2_Module.Utils.Text;          use Vdiff2_Module.Utils.Text;

package body Vdiff2_Command_Line is

   use Diff_Head_List;
   use Diff_Chunk_List;

   -------------
   -- Execute --
   -------------

   function Execute
     (Command : access Diff_Command_Line;
      Context : Interactive_Command_Context) return Command_Return_Type
   is
   pragma Unreferenced (Context);
   begin
      return Execute (Command);
   end Execute;

   -------------
   -- Execute --
   -------------

   function Execute
     (Command : access Diff_Command_Line) return Command_Return_Type
   is
      Diff : constant Diff_Head_Access := new Diff_Head;
   begin

      if Command.Head /= Diff_Head_List.Null_Node
        and Command.Line > 0
        and Command.Action /= null
      then
         Diff.all := Data (Command.Head);
         Diff.Current_Node := Is_In_Diff_Chunk_List
           (Command.File, Diff.all, Command.Line);

         if Diff.Current_Node /= Diff_Chunk_List.Null_Node then
            Command.Action (Command.Kernel, Diff,
                            Command.Line, Command.File);
         end if;
      end if;

      return Commands.Success;

   exception
      when others =>
         return Failure;
   end Execute;

   ------------
   -- Create --
   ------------

   procedure Create
     (Item      : out Diff_Command_Line_Access;
      Kernel    : Kernel_Handle;
      List_Diff : Diff_Head_List_Access;
      File      : Virtual_File;
      Line      : Natural;
      Action    : Vdiff2_Command_Line.Handler_Action_Line) is
   begin

      Item           := new Diff_Command_Line;
      Item.Kernel    := Kernel;
      Item.List_Diff := List_Diff;
      Item.File      := File;
      Item.Line      := Line;
      Item.Action    := Action;
      Item.Head      := Is_In_Diff_List (File, List_Diff.all);
   end Create;

   ---------------------------
   -- Is_In_Diff_Chunk_List --
   ---------------------------

   function Is_In_Diff_Chunk_List
     (Selected_File : Virtual_File;
      Item          : Diff_Head;
      Line          : Natural)
      return Diff_Chunk_List.List_Node
   is
      List      : constant Diff_Chunk_List.List := Item.List;
      Curr_Node : Diff_Chunk_List.List_Node := First (List);
      Diff      : Diff_Chunk_Access;

   begin

      while Curr_Node /= Diff_Chunk_List.Null_Node
      loop
         Diff := Data (Curr_Node);

         if Selected_File = Item.File1 then
            exit when Diff.Range1.First <= Line
              and then Diff.Range1.Last >= Line;

         elsif Selected_File = Item.File2 then
            exit when Diff.Range2.First <= Line
              and then Diff.Range2.Last >= Line;

         elsif Item.File3 /= VFS.No_File
           and then Selected_File = Item.File3
         then
            exit when Diff.Range3.First <= Line
              and then Diff.Range3.Last >= Line;
         end if;

         Curr_Node := Next (Curr_Node);
      end loop;

      return Curr_Node;
   end Is_In_Diff_Chunk_List;

   ------------------------
   --  Move_On_Ref_File  --
   ------------------------

   procedure Move_On_Ref_File
     (Kernel : Kernel_Handle;
      Diff   : Diff_Head_Access;
      Line   : Natural := 0;
      File   : Virtual_File := VFS.No_File)
   is
      Diff1     : Diff_Chunk_Access;
      VFile    : T_VFile;
      VRange   : T_VRange;
      Num_File : T_Loc := 0;
      pragma Unreferenced (Line);

   begin
      Diff1 := Data (Diff.Current_Node);

      VRange (1) := Data (Diff.Current_Node).Range1;
      VRange (2) := Data (Diff.Current_Node).Range2;
      VRange (3) := Data (Diff.Current_Node).Range3;
      VFile (1) := Diff.File1;
      VFile (2) := Diff.File2;
      VFile (3) := Diff.File3;

      for J in VFile'Range loop
         if File = VFile (J) then
            Num_File := J;
            exit;
         end if;
      end loop;

      if Num_File = Diff.Ref_File or Num_File = 0 then
         return;
      end if;

      Move_Block (Kernel, VFile (Num_File), VFile (Diff.Ref_File),
                  VRange (Num_File), VRange (Diff.Ref_File));

      declare
         Info           : constant Line_Information_Data :=
           new Line_Information_Array
             (VRange (Num_File).First - 1 .. VRange (Num_File).First - 1);
         Null_Line_Info : Line_Information_Record;

      begin
         Info (Info'First) := Null_Line_Info;
         Add_Line_Information
           (Kernel, File, "Vdiff2_Col_Merge",
            Info);
         Unhighlight_Block
           (Kernel, VFile (Num_File), VRange (Num_File), "Change_diff");
         Unhighlight_Block
           (Kernel, VFile (Num_File), VRange (Num_File), "Append_diff");
      end;

      Diff1.Range1 := VRange (1);
      Diff1.Range2 := VRange (2);
      Diff1.Range3 := VRange (3);
   end Move_On_Ref_File;

   --------------------------
   -- Delete_From_Ref_File --
   --------------------------

   procedure Delete_From_Ref_File
     (Kernel : Kernel_Handle;
      Diff   : Diff_Head_Access;
      Line   : Natural := 0;
      File   : Virtual_File := VFS.No_File)
   is
      Diff1     : Diff_Chunk_Access;
      VFile    : T_VFile;
      VRange   : T_VRange;
      Num_File : T_Loc := 0;
      Other    : T_Loc := 0;
      pragma Unreferenced (Line);

   begin
      Diff1 := Data (Diff.Current_Node);

      VRange (1) := Data (Diff.Current_Node).Range1;
      VRange (2) := Data (Diff.Current_Node).Range2;
      VRange (3) := Data (Diff.Current_Node).Range3;
      VFile (1) := Diff.File1;
      VFile (2) := Diff.File2;
      VFile (3) := Diff.File3;

      for J in VFile'Range loop
         if File = VFile (J) then
            Num_File := J;
            exit;
         end if;
      end loop;

      for J in VFile'Range loop
         if J /= Diff.Ref_File and J /= Num_File then
            Other := J;
            exit;
         end if;
      end loop;

      if Num_File = Diff.Ref_File or Num_File = 0 then
         return;
      end if;

      Delete_Block (Kernel, VFile (Diff.Ref_File),
                    VRange (Num_File), VRange (Diff.Ref_File));

      declare
         Info           : constant Line_Information_Data :=
           new Line_Information_Array
             (VRange (Num_File).First - 1 .. VRange (Num_File).First - 1);
         Null_Line_Info : Line_Information_Record;

      begin
         Info (Info'First) := Null_Line_Info;
         Add_Line_Information
           (Kernel, File, "Vdiff2_Col_Merge",
            Info);
         Unhighlight_Block
           (Kernel, VFile (Num_File), VRange (Num_File), "Change_diff");
         Unhighlight_Block
           (Kernel, VFile (Num_File), VRange (Num_File), "Append_diff");
      end;

      VRange (Num_File).Blank_Lines_Mark :=
        Add_Line
          (Kernel, VFile (Num_File),
           VRange (Num_File).First,
           "Default_diff",
           (VRange (Other).Last - VRange (Other).First));

      VRange (Diff.Ref_File).Blank_Lines_Mark :=
        Add_Line
          (Kernel, VFile (Diff.Ref_File),
           VRange (Diff.Ref_File).First,
           "Default_diff",
           (VRange (Other).Last - VRange (Other).First));

      Diff1.Range1 := VRange (1);
      Diff1.Range2 := VRange (2);
      Diff1.Range3 := VRange (3);
   end Delete_From_Ref_File;
end Vdiff2_Command_Line;
