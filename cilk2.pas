unit cilk2;

interface

uses
  System.SysUtils,
  System.Classes,
  System;

type
  ICilk = interface;

  Targs = record
    ICilk: ICilk;
    function spawn<T>(a: T; const p: TProc<T>): ICilk; overload;
    function spawn<T1, T2>(a1: T1; a2: T2; const p: TProc<T1, T2>): ICilk; overload;
  end;

  ICilk = interface
  ['{97CE2295-4885-4966-8CB3-6DF72AF28F74}']
    function spawn(const p: TProc): ICilk;
    function args: Targs;
    function sync: ICilk;
  end;

function newCilk: ICilk;

implementation

uses
  Winapi.Windows;

const
  MAX_TASKS = 16;

type
  PTask = ^TTask;

  TTask = record
    Count: PInteger;
    ErrorCount: PInteger;
    Proc: TProc;
    Work: PTP_WORK;
  end;

  TCilk = class(TInterfacedObject, ICilk)
  private
    FTasks: array[0..MAX_TASKS - 1] of TTask;
    FNextTask: Integer;
    FCount: Integer;
    FErrorCount: Integer;
    function spawn(const p: TProc): ICilk;
    function args: Targs;
    function sync: ICilk;
    procedure _sync; inline;
  public
    constructor Create;
    destructor Destroy; override;
  end;

procedure __stdcall WorkCallback(Instance: PTP_CALLBACK_INSTANCE; Context: Pointer; Work: PTP_WORK); stdcall;
var
  task: PTask;
begin
  task := Context;
  try
    task.Proc();
  except
    InterlockedIncrement(task.ErrorCount^);
  end;
  InterlockedDecrement(task.Count^);
end;

{ TCilk }

constructor TCilk.Create;
var
  i: Integer;
begin
  inherited Create;

  FNextTask := 0;
  FCount := 0;
  FErrorCount := 0;

  for i := 0 to MAX_TASKS - 1 do
  begin
    FTasks[i].Count := @FCount;
    FTasks[i].ErrorCount := @FErrorCount;
    FTasks[i].Work := nil; // ленивое создание
  end;
end;

destructor TCilk.Destroy;
var
  i: Integer;
begin
  _sync;

  for i := 0 to MAX_TASKS - 1 do
    if FTasks[i].Work <> nil then
      CloseThreadpoolWork(FTasks[i].Work);

  inherited;
end;

function TCilk.spawn(const p: TProc): ICilk;
var
  task: PTask;
begin
  Result := Self;

  if FNextTask >= MAX_TASKS then
  begin
    Inc(FErrorCount);
    Exit;
  end;

  task := @FTasks[FNextTask];
  Inc(FNextTask);

  task.Proc := p;

  if task.Work = nil then
    task.Work := CreateThreadpoolWork(@WorkCallback, task, nil);

  InterlockedIncrement(FCount);

  SubmitThreadpoolWork(task.Work);
end;

function Targs.spawn<T>(a: T; const p: TProc<T>): ICilk;
begin
  Result := ICilk;
  Result.spawn(
    procedure
    begin
      p(a);
    end
  );
end;

function Targs.spawn<T1, T2>(a1: T1; a2: T2; const p: TProc<T1, T2>): ICilk;
begin
  Result := ICilk;
  Result.spawn(
    procedure
    begin
      p(a1, a2);
    end
  );
end;

function TCilk.args: Targs;
begin
  Result.ICilk := Self;
end;

function TCilk.sync: ICilk;
begin
  Result := Self;
  _sync;
end;

procedure TCilk._sync;
begin
  while InterlockedCompareExchange(FCount, 0, 0) <> 0 do
    System.YieldProcessor;

  FNextTask := 0;
end;

function newCilk: ICilk;
begin
  Result := TCilk.Create;
end;

initialization
  IsMultiThread := True;

end.
