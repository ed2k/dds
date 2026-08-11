unit DDS_SolverContext;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DDS_Types, DDS_TransTable;

type
  TSolverContext = class;

  TSearchContext = class
  private
    FOwner: TSolverContext;
    FTransTable: TTransTableS;
  public
    constructor Create(AOwner: TSolverContext);
    destructor Destroy; override;
    function node_type_store(hand: LongInt): LongInt;
    function ini_depth: LongInt;
    function trans_table: TTransTableS;
  end;

  TSolverContext = class
  private
    FThreadData: PThreadData;
    FSearchContext: TSearchContext;
    FTransTable: TTransTableS;
    FOwnsThreadData: Boolean;
    FMoveGen: TObject;
  public
    constructor Create(AThreadData: PThreadData = nil);
    destructor Destroy; override;
    function thread_ptr: PThreadData;
    function search: TSearchContext;
    function trans_table: TTransTableS;
    function move_gen: TObject;
  end;

implementation

uses
  DDS_Moves;

{ TSearchContext }

constructor TSearchContext.Create(AOwner: TSolverContext);
begin
  inherited Create;
  FOwner := AOwner;
  FTransTable := nil;
end;

destructor TSearchContext.Destroy;
begin
  if FTransTable <> nil then
    FTransTable.Free;
  inherited Destroy;
end;

function TSearchContext.node_type_store(hand: LongInt): LongInt;
begin
  Result := FOwner.thread_ptr^.nodeTypeStore[hand];
end;

function TSearchContext.ini_depth: LongInt;
begin
  Result := FOwner.thread_ptr^.iniDepth;
end;

function TSearchContext.trans_table: TTransTableS;
begin
  if FTransTable = nil then
  begin
    FTransTable := TTransTableS.Create;
  end;
  Result := FTransTable;
end;

{ TSolverContext }

constructor TSolverContext.Create(AThreadData: PThreadData);
begin
  inherited Create;
  if AThreadData = nil then
  begin
    FThreadData := AllocMem(SizeOf(ThreadData));
    FOwnsThreadData := true;
  end
  else
  begin
    FThreadData := AThreadData;
    FOwnsThreadData := false;
  end;
  FSearchContext := TSearchContext.Create(Self);
  FTransTable := TTransTableS.Create;
  FMoveGen := TMoves.Create;
end;

destructor TSolverContext.Destroy;
begin
  FMoveGen.Free;
  FSearchContext.Free;
  FTransTable.Free;
  if FOwnsThreadData then
    FreeMem(FThreadData);
  inherited Destroy;
end;

function TSolverContext.thread_ptr: PThreadData;
begin
  Result := FThreadData;
end;

function TSolverContext.search: TSearchContext;
begin
  Result := FSearchContext;
end;

function TSolverContext.trans_table: TTransTableS;
begin
  Result := FTransTable;
end;

function TSolverContext.move_gen: TObject;
begin
  Result := FMoveGen;
end;

end.
