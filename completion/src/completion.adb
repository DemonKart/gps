-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2006                         --
--                              AdaCore                              --
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

with Ada.Unchecked_Deallocation;
with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Completion is

   use Completion_List_Pckg;

   ----------
   -- Free --
   ----------

   procedure Free (List : in out Completion_List) is
   begin
      Free (List.List);
      Free (List.Searched_Identifier);
   end Free;

   --------------------------
   -- Get_Completed_String --
   --------------------------

   function Get_Completed_String (This : Completion_List) return String
   is
   begin
      if This.Searched_Identifier /= null then
         return This.Searched_Identifier.all;
      else
         return "";
      end if;
   end Get_Completed_String;

   ----------
   -- Next --
   ----------

   function Next
     (Resolver : access Completion_Resolver'Class)
      return Completion_Resolver_Access
   is
      It : Completion_Resolver_List_Pckg.List_Node := First
        (Resolver.Manager.Resolvers);
   begin
      while It /= Completion_Resolver_List_Pckg.Null_Node loop
         if Data (It) = Completion_Resolver_Access (Resolver) then
            if Next (It) /= Completion_Resolver_List_Pckg.Null_Node then
               return Data (Next (It));
            else
               return null;
            end if;
         end if;

         It := Next (It);
      end loop;

      return null;
   end Next;

   ----------------
   -- Set_Buffer --
   ----------------

   procedure Set_Buffer
     (Manager : in out Completion_Manager; Buffer : String_Access)
   is
   begin
      Manager.Buffer := Buffer;
   end Set_Buffer;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Completion_Manager_Access) is
      procedure Internal_Free is new
        Ada.Unchecked_Deallocation
          (Completion_Manager'Class, Completion_Manager_Access);
   begin
      Free (This.Resolvers, False);
      Internal_Free (This);
   end Free;

   ----------------
   -- Get_Buffer --
   ----------------

   function Get_Buffer (Manager : Completion_Manager) return String_Access is
   begin
      return Manager.Buffer;
   end Get_Buffer;

   -----------------------
   -- Register_Resolver --
   -----------------------

   procedure Register_Resolver
     (Manager  : access Completion_Manager;
      Resolver : access Completion_Resolver'Class) is
   begin
      Append (Manager.Resolvers, Completion_Resolver_Access (Resolver));
      Resolver.Manager := Completion_Manager_Access (Manager);
   end Register_Resolver;

   ----------
   -- Free --
   ----------

   procedure Free (Resolver : in out Completion_Resolver_Access) is
      procedure Internal_Free is new
        Ada.Unchecked_Deallocation
          (Completion_Resolver'Class, Completion_Resolver_Access);
   begin
      Free (Resolver.all);
      Internal_Free (Resolver);
   end Free;

   -------------------
   -- Free_Proposal --
   -------------------

   procedure Free_Proposal (Proposal : in out Completion_Proposal'Class) is
      pragma Unreferenced (Proposal);
   begin
      null;
   end Free_Proposal;

   --------------
   -- Set_Mode --
   --------------

   procedure Set_Mode
     (Proposal : in out Completion_Proposal; Mode : Proposal_Mode)
   is
   begin
      Proposal.Mode := Mode;
   end Set_Mode;

   ---------------
   -- Get_Label --
   ---------------

   function Get_Label
     (Proposal : Completion_Proposal)  return UTF8_String is
   begin
      return Get_Completion (Completion_Proposal'Class (Proposal));
   end Get_Label;

   ------------
   -- Get_Id --
   ------------

   function Get_Id (Proposal : Completion_Proposal)
      return UTF8_String is
   begin
      return Get_Completion (Completion_Proposal'Class (Proposal));
   end Get_Id;

   -----------------------
   -- Get_Documentation --
   -----------------------

   function Get_Documentation
     (Proposal : Completion_Proposal) return UTF8_String
   is
      pragma Unreferenced (Proposal);
   begin
      return "";
   end Get_Documentation;

   ------------------
   -- Get_Location --
   ------------------

   function Get_Location (Proposal : Completion_Proposal) return File_Location
   is
      pragma Unreferenced (Proposal);
   begin
      return Null_File_Location;
   end Get_Location;

   -----------------------
   -- Append_Expression --
   -----------------------

   procedure Append_Expression
     (Proposal             : in out Completion_Proposal;
      Number_Of_Parameters : Natural)
   is
      pragma Unreferenced (Proposal, Number_Of_Parameters);
   begin
      null;
   end Append_Expression;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (Proposal : Completion_Proposal) return Boolean is
      pragma Unreferenced (Proposal);
   begin
      return True;
   end Is_Valid;

   -----------------
   -- Get_Manager --
   ------------------

   function Get_Resolver (Proposal : Completion_Proposal)
     return Completion_Resolver_Access is
   begin
      return Completion_Resolver_Access (Proposal.Resolver);
   end Get_Resolver;

   -----------
   -- First --
   -----------

   function First (This : Completion_List) return Completion_Iterator is
      It : Completion_Iterator := (It => First (This.List));
   begin
      while not Is_Valid (It) loop
         Next (It);
      end loop;

      return It;
   end First;

   ----------
   -- Next --
   ----------

   procedure Next (This : in out Completion_Iterator) is
   begin
      Next (This.It);

      while not Is_Valid (This) loop
         Next (This.It);
      end loop;
   end Next;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (It : Completion_Iterator) return Boolean is
   begin
      return At_End (It) or else Is_Valid (Get_Proposal (It));
   end Is_Valid;

   ------------------
   -- Get_Proposal --
   ------------------

   function Get_Proposal
     (This : Completion_Iterator) return Completion_Proposal'Class is
   begin
      return Get (This.It);
   end Get_Proposal;

   --------------------
   -- Get_Completion --
   --------------------

   function Get_Completion
     (Proposal : Simple_Completion_Proposal) return UTF8_String is
   begin
      return Proposal.Name.all;
   end Get_Completion;

   ------------------
   -- Get_Category --
   ------------------

   function Get_Category
     (Proposal : Simple_Completion_Proposal) return Language_Category
   is
      pragma Unreferenced (Proposal);
   begin
      return Cat_Unknown;
   end Get_Category;

   ---------------------
   -- Get_Composition --
   ---------------------

   procedure Get_Composition
     (Proposal   : Simple_Completion_Proposal;
      Identifier : String;
      Offset     : Positive;
      Is_Partial : Boolean;
      Result     : in out Completion_List)
   is
      pragma Unreferenced (Proposal, Identifier, Offset, Is_Partial, Result);
   begin
      null;
   end Get_Composition;

   ------------------------------
   -- Get_Number_Of_Parameters --
   ------------------------------

   function Get_Number_Of_Parameters
     (Proposal : Simple_Completion_Proposal) return Natural
   is
      pragma Unreferenced (Proposal);
   begin
      return 0;
   end Get_Number_Of_Parameters;

   ----------
   -- Free --
   ----------

   procedure Free (Proposal : in out Simple_Completion_Proposal) is
   begin
      Free (Proposal.Name);
   end Free;

   -----------
   -- Match --
   -----------

   function Match
     (Seeked_Name, Tested_Name : String; Is_Partial : Boolean) return Boolean
   is
   begin
      if (not Is_Partial and then Seeked_Name'Length /= Tested_Name'Length)
        or else Seeked_Name'Length > Tested_Name'Length
      then
         return False;
      end if;

      for J in 1 .. Seeked_Name'Length loop
         if To_Lower (Tested_Name (J + Tested_Name'First - 1)) /=
           To_Lower (Seeked_Name (J + Seeked_Name'First - 1))
         then
            return False;
         end if;
      end loop;

      return True;
   end Match;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Completion_Iterator) is
   begin
      Free (This.It);
   end Free;

   ------------
   -- At_End --
   ------------

   function At_End (This : Completion_Iterator) return Boolean is
   begin
      return At_End (This.It);
   end At_End;

end Completion;
