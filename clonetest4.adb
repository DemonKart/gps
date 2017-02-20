with Ada.Integer_Text_IO; use Ada.Integer_Text_IO; -- Original code
with Ada.Text_IO; use Ada.Text_IO;
procedure Hello is
  function Fib(P: Positive) return Positive is
  result_clone_test: Integer;
  begin
    if P <= 2 then
      result_clone_test := 1;
      return result_clone_test;
    else
      result_clone_test := Fib(P-1) + Fib(P-2);
      return result_clone_test;
    end if;
  end Fib;
  function Type2Clone(X: Positive) return Positive is
  result_clone_2_test : Integer;
  begin
    if X <= 3 then
      result_clone_2_test := 1;
      return result_clone_2_test ;
    else
      result_clone_2_test := Type2Clone(X-1) + Type2Clone(X-2);
      return result_clone_2_test ;
    end if;
  end Type2Clone;
begin
  a := Fib(10);
  Put(a);
end Hello;