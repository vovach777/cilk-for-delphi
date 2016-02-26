# Introduction #

Cilk is a general-purpose programming language designed for multithreaded parallel computing.
To implements cilk instruction, we use Delphi interface called ICilk.
They are very simple:

```
procedure Test;
var
  i, j : integer;
  Cilk : ICilk;
begin
 newCilk //Create new ICilk interface
 .spawn(
   procedure
   begin
     //do some parallel work here...
     i := 42; //result of work
   end)
 .spawn(
   procedure
   begin
     //do some parallel work here...
     j := 42; //result of work
   end)
 .sync; //wait for i and j calculation well done
 assert(i = 42);
 assert(j = 42); 
// or you can use variable Cilk : ICilk
 Cilk := newCilk;
 Cilk.spawn(
   procedure
   begin
     //do some work here...
     i := 42; //result of work
   end);
  //Do Some work...
 Cilk.spawn(
   procedure
   begin
     //do some work here...
     j := 42; //result of work
   end);
 //Do enother work here...
 Cilk.sync; //and sync result 
end;
```