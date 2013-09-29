unit cilk;

interface
uses windows,SysUtils,Classes;


  type
    ICilk = interface;
    Targs = record
     ICilk : ICilk;
     function spawn<T>(a:T; const p : TProc<T>) : ICilk;overload;
     function spawn<T1,T2>(a1:T1; a2:T2; const p : TProc<T1,T2>) : ICilk; overload;
    end;
    ICilk = interface
    ['{97CE2295-4885-4966-8CB3-6DF72AF28F74}']
       function spawn(const p : TProc) : ICilk;
       function args : Targs;
       function sync : ICilk;
    end;

    function newCilk : ICilk;

implementation

type
    TCilk = class(TInterfacedObject, ICilk)
       FCount : integer;
       FErrorCount : integer;
       function spawn(const  p : TProc) : ICilk;
       function args : Targs;
       function sync : ICilk;
       destructor Destroy; override;
  private
    end;

  PProc = ^TProc;
  PTask = ^TTask;


  TTask = record
     Count : PInteger;
     ErrorCount : PInteger;
     Proc  : TProc;
  end;

 function __ThreadStartRoutine(lpThreadParameter: Pointer): Integer stdcall;
 var
   task : PTask;
 begin
   task := lpThreadParameter;
   try
     task.Proc();
   except
     InterlockedIncrement( task.ErrorCount^ );
   end;
   InterlockedDecrement(task.Count^);
   Dispose(task);
   result := 0;
 end;


{ TCilk }

destructor TCilk.Destroy;
begin
  sync;
  inherited;
end;

function TCilk.spawn(const p: TProc) : ICilk;
var
  task : PTask;
begin
  result := self;
  new(task);
  InterlockedIncrement(FCount);
  task.Count := @FCount;
  task.ErrorCount := @FErrorCount;
  task.Proc := p;
  if not QueueUserWorkItem(__ThreadStartRoutine,task,WT_EXECUTELONGFUNCTION) then
  begin
     dispose(task);
     InterlockedDecrement(FCount);
     InterlockedIncrement(FErrorCount);
  end;
end;

function Targs.spawn<T>(a:T; const p:TProc<T>) : ICilk;
begin
  result := ICilk;
  result.spawn(
    procedure
    begin
       p(a);
    end);
end;
function Targs.spawn<T1,T2>(a1:T1;a2:T2; const p:TProc<T1,T2>) : ICilk;
begin
  result := ICilk;
  result.spawn(
    procedure
    begin
       p(a1,a2);
    end);
end;

function TCilk.args : Targs;
begin
  result.ICilk := self;
end;


function TCilk.sync : ICilk;
begin
  result := self;
  while FCount > 0 do
     TThread.SpinWait(FCount);
end;


    function newCilk : ICilk;
    begin
      Result := TCilk.Create;
    end;

Initialization
  IsMultiThread := true;
finalization

end.
