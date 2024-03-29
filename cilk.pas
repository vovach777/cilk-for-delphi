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
       FCountIsZero: THandle;
       function spawn(const  p : TProc) : ICilk;
       function args : Targs;
       function sync : ICilk;
       procedure _sync; inline;
       constructor Create;
       destructor Destroy; override;
  private
    end;

  PProc = ^TProc;
  PTask = ^TTask;


  TTask = record
     Count : PInteger;
     ErrorCount : PInteger;
     CountIsZero : PHandle;
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
   if InterlockedDecrement(task.Count^) = 0 then
     SetEvent(task.CountIsZero^);
   Dispose(task);
   result := 0;
 end;


{ TCilk }

constructor TCilk.Create;
begin
  FCountIsZero := CreateEvent(nil,false,false,nil);
end;

destructor TCilk.Destroy;
begin
  _sync;
  CloseHandle(FCountIsZero);
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
  task.CountIsZero := @FCountIsZero;
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
  _sync;
end;

procedure TCilk._sync;
begin
  if InterlockedCompareExchange(FCount,0,0) <> 0 then
  begin
     WaitForSingleObject(FCountIsZero,INFINITE);
  end;
end;

function newCilk : ICilk;
begin
  Result := TCilk.Create;
end;

Initialization
  IsMultiThread := true;
finalization

end.
