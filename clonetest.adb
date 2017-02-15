with Ada.Integer_Text_IO; use Ada.Integer_Text_IO; -- Original code
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;
-- 1: Type-1 Clone
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO; 
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;
-- 2: Type-1 Clone
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin -- Comments
        if P <= 2 then
            return 1;
            -- Blank line
        else
            return Fib(P-1) + Fib(P-2);
        end if;
        -- Blank line
    end Fib;
    a : Integer;
begin -- Comments
  a := Fib(10);
  Put(a);
end Hello;
-- 3: Type-2 Clone
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;

with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;

with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;

with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;

with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;

with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;

with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
    begin
        if P <= 2 then
            return 1;
        else
            return Fib(P-1) + Fib(P-2);
        end if;
    end Fib;
    a : Integer;
begin
  a := Fib(10);
  Put(a);
end Hello;
