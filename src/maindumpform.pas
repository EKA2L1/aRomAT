unit MainDumpForm;

{$MODE Delphi}
{$ASMMODE intel}

interface

uses
  LCLIntf, LCLType, SysUtils, Variants, Classes,
  Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, Grids, ComCtrls, Generics.Collections,
  DBGrids, ExtCtrls, Menus, Windows, StrUtils, CryptUtils, FileUtils,
  RomExplorer;

type

  { TMainForm }

  TMainForm = class(TForm)
    LoadDumpBtn: TBitBtn;
    OpenDialog: TOpenDialog;
    Label1: TLabel;
    ExtractSelectedBtn: TBitBtn;
    SaveDialog: TSaveDialog;
    CheckDSOBtn: TBitBtn;
    ProcessExportsBtn: TBitBtn;
    MakeIDCSelectedBtn: TBitBtn;
    SearchBoxEdit: TEdit;
    CreditLabel: TLabel;
    ExtractAllBtn: TBitBtn;
    MakeIDCAllBtn: TBitBtn;
    MakeDICBtn: TBitBtn;
    ConvertedToE32Btn: TBitBtn;
    Memo: TMemo;
    HideLogBtn: TBitBtn;
    SearchBoxLabel: TLabel;
    SaveSeperateCBox: TCheckBox;
    ShowLogInfoLabel: TLabel;
    ShowLinkBtn: TBitBtn;
    SaveLogBtn: TBitBtn;
    PopupMenu: TPopupMenu;
    SelectAlIMenuItem: TMenuItem;
    CopyToClipboardMenuItem: TMenuItem;
    Label6: TLabel;
    ShowLogCBox: TCheckBox;
    StringGrid1: TStringGrid;
    RemoveSelectionBtn: TBitBtn;
    procedure LoadDumpBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ExtractSelectedBtnClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CheckDSOBtnClick(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure ProcessExportsBtnClick(Sender: TObject);
    procedure ShowLogInfo3LabelClick(Sender: TObject);
    procedure StringGrid1EndDock(Sender, Target: TObject; X, Y: integer);
    procedure MakeIDCSelectedBtnClick(Sender: TObject);
    procedure ExtractAllBtnClick(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure BitBtn6Click(Sender: TObject);
    procedure MakeIDCAllBtnClick(Sender: TObject);
    procedure MakeDICBtnClick(Sender: TObject);
    procedure ConvertedToE32BtnClick(Sender: TObject);
    procedure HideLogBtnClick(Sender: TObject);
    procedure ShowLinkBtnClick(Sender: TObject);
    procedure SaveLogBtnClick(Sender: TObject);
    procedure SelectAlIMenuItemClick(Sender: TObject);
    procedure CopyToClipboardMenuItemClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; ACol, ARow: integer;
      Rect: TRect; State: TGridDrawState);
    procedure RemoveSelectionBtnClick(Sender: TObject);
    procedure StringGrid1KeyPress(Sender: TObject; var Key: char);
    procedure StringGrid1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: integer);
    procedure SearchBoxEditKeyPress(Sender: TObject; var Key: char);
  private
    {$IFDEF WINDOWS}
    procedure WMDropFiles(var Msg: TWMDropFiles);
      message WM_DROPFILES;
    {$ENDIF}
  public
    { Public declarations }
  end;

type
  tDic = array [0 .. 5] of string;

type
  mDic = array [0 .. 1] of integer;

type
  words = array of word;

type
  dwords = array of dword;

const
  NAME_COLUMN = 1;
  SIZE_IMAGE_COLUMN = 2;
  ADDR_IMAGE_COLUMN = 3;

var
  MainForm: TMainForm;
  FSm: TFileStream;
  FS: TMemoryStream;
  NamesArray: TDictionary<longint, string>;
  dicM: TDictionary<dword, mDic>;
  dicT: TDictionary<integer, tDic>;
  dicRloc: TDictionary<longint, words>;
  dicDataRloc: TDictionary<longint, words>;
  dicImp: TDictionary<dword, dwords>;
  romExplorer: TRomExplorer;
  sgsel: TStringList;

implementation

{$R *.lfm}

procedure TMainForm.CheckBox1Click(Sender: TObject);
begin
  ShowMessage(IntToStr(StringGrid1.Row));
end;

procedure TMainForm.CopyToClipboardMenuItemClick(Sender: TObject);
begin
  Memo.CopyToClipboard;
end;

procedure GridSort(SG: TStringGrid; ByColNumber, FromRow, ToRow: integer);
var
  Temp: TStringList;

  procedure QuickSort(Lo, Hi: integer; CC: TStrings);

    procedure Sort(l, r: integer);
    var
      i, j: integer;
      X: string;
    begin
      i := l;
      j := r;
      X := CC[(l + r) div 2];
      repeat
        while CC[i] < X do
          Inc(i);
        while X < CC[j] do
          Dec(j);
        if i <= j then
        begin
          Temp.Assign(SG.Rows[j]); // Ìåíÿåì ìåñòàìè 2 ñòðîêè
          SG.Rows[i].BeginUpdate;
          SG.Rows[j].BeginUpdate;

          SG.Rows[j].Assign(SG.Rows[i]);
          SG.Rows[i].Assign(Temp);

          SG.Rows[i].EndUpdate;
          SG.Rows[j].EndUpdate;

          Inc(i);
          Dec(j);
        end;
      until i > j;
      if l < j then
        Sort(l, j);
      if i < r then
        Sort(i, r);
    end;

  begin
    { quicksort } ;
    Sort(Lo, Hi);
  end;

begin
  Temp := TStringList.Create;
  QuickSort(FromRow, ToRow, SG.Cols[ByColNumber]);
  Temp.Free;
end;

procedure LoadDump(path: string);
type
  TRomEntryStack = TStack<TRomEntry>;
var
  signature, currentPos: dword;
  i: longint;
  encoding: TEncoding;
  entryTemp: TRomEntry;
  dirSearchList: TRomEntryStack;

begin
  MainForm.OpenDialog.FileName := path;
  MainForm.StringGrid1.Visible := False;

  MainForm.StringGrid1EndDock(nil, nil, 0, 0);

  FS := TMemoryStream.Create;
  FS.LoadFromFile(path);

  romExplorer := TRomExplorer.Create(TStream(FS));
  encoding := TEncoding.Unicode;
  dirSearchList := TRomEntryStack.Create;

  if not (romExplorer.GetRomEntry('sys\bin\', entryTemp)) then
  begin
    if (romExplorer.GetRomEntry('system\libs\', entryTemp)) then
    begin
      dirSearchList.Push(entryTemp);

      if (romExplorer.GetRomEntry('system\programs\', entryTemp)) then
        dirSearchList.Push(entryTemp);
    end;
  end
  else
    dirSearchList.Push(entryTemp);

  i := 0;
  signature := 0;
  while dirSearchList.Count > 0 do
  begin
    entryTemp := dirSearchList.Pop;
    if not romExplorer.BeginDirIterate(entryTemp) then
    begin
      break;
    end;

    while (romExplorer.GetNextEntry(entryTemp, encoding)) do
    begin
      if (entryTemp.iAttrib and $10 <> 0) then
        continue;

      currentPos := FS.Position;
      FS.Seek(romExplorer.RomToOffset(entryTemp.iDataAddr) + $10, soBeginning);
      FS.Read(signature, 4);

      if (signature <> $434F5045) and (romExplorer.RomToOffset(entryTemp.iDataAddr) < FS.Size) and
        (romExplorer.RomToOffset(entryTemp.iDataAddr) + entryTemp.iFileSize + $78 < FS.Size + 2) then
      begin
        MainForm.StringGrid1.Rows[MainForm.StringGrid1.RowCount - 1][0] := ' ';
        MainForm.StringGrid1.Rows[MainForm.StringGrid1.RowCount - 1][1] :=
          AnsiString(LowerCase(entryTemp.iName));
        MainForm.StringGrid1.Rows[MainForm.StringGrid1.RowCount - 1][2] :=
          inttohex(entryTemp.iFileSize, 8);
        MainForm.StringGrid1.Rows[MainForm.StringGrid1.RowCount - 1][3] := inttohex(
          entryTemp.iDataAddr, 8);
        MainForm.StringGrid1.RowCount := MainForm.StringGrid1.RowCount + 1;
      end;

      Inc(i);
      if i = 200 then
      begin
        Application.ProcessMessages;
        i := 0;
      end;

      FS.Seek(currentPos, soBeginning);
    end;

    romExplorer.EndDirIterate;
  end;

  FS.Seek(0, 0);
  MainForm.StringGrid1.RowCount := MainForm.StringGrid1.RowCount - 1;
  GridSort(MainForm.StringGrid1, 1, 1, MainForm.StringGrid1.RowCount - 1);

  MainForm.StringGrid1.Visible := True;

  MainForm.ExtractSelectedBtn.Enabled := True;
  MainForm.CheckDSOBtn.Enabled := True;
  MainForm.ProcessExportsBtn.Enabled := True;
end;

procedure Delay(Milliseconds: integer);
{ by Hagen Reddmann }
var
{$ifdef WINDOWS}
  Tick: dword;
  Event: THandle;
{$endif}
begin
  {$ifdef WINDOWS}
  Event := CreateEvent(nil, False, False, nil);
  try
    Tick := GetTickCount + dword(Milliseconds);
    while (Milliseconds > 0) and
      (MsgWaitForMultipleObjects(1, Event, False, Milliseconds, QS_ALLINPUT) <>
        WAIT_TIMEOUT) do
    begin
      Application.ProcessMessages;
      Milliseconds := Tick - GetTickCount;
    end;
  finally
    FileClose(Event); { *Converted from CloseHandle* }
  end;
  {$else}
  { Just sleep, although we can't process messages in here... }
  Sleep(Milliseconds);
  {$endif}
end;

procedure SaveFile(path: string; num: integer);
var
  SB: TFileStream;
  Size: longint;
begin
  SB := TFileStream.Create(path, fmOpenWrite or fmCreate);
  FS.Seek(romExplorer.RomToOffset(StrToInt('$' + MainForm.StringGrid1.Rows[num][3])), 0);
  Size := $78 + StrToInt('$' + MainForm.StringGrid1.Rows[num][2]);
  if FS.Position + Size < FS.Size then
    SB.CopyFrom(FS, Size);
  SB.Free;
end;

procedure WriteBytes(bytes: TBytes; val: dword);
var
  i, oldlen: integer;
begin
  oldlen := Length(bytes);
  SetLength(bytes, Length(bytes) + SizeOf(val));
  for i := 1 to SizeOf(val) do
    bytes[oldlen + i] := val and (i * $100 * $FF) div (i * $100);
end;

procedure TMainForm.HideLogBtnClick(Sender: TObject);
begin
  StringGrid1.Height := ClientHeight - 47;
  StringGrid1.Anchors := StringGrid1.Anchors + [akBottom];
  Memo.Visible := False;
  HideLogBtn.Visible := False;
  SaveLogBtn.Visible := False;
end;

function ReadAnImportOutLoud(Stream: TStream; var buf: dword): byte;
var
  lastRomPosition: qword;
  isOldExport: boolean;
begin
  Stream.Read(buf, 4);

  { LDR PC, [PC, #-4] , basically jump stub }
  { In some case it's thumb with LDR R3, [PC, #0], address aligned by 4 }
  if (buf = $E51FF004) or (buf and ($FFFF) = $4B01) then
  begin
    ReadAnImportOutLoud := 1;

    if (buf and ($FFFF) = $4B01) then
    begin
      // Skip 4 bytes
      FS.Seek(4, soCurrent);
      isOldExport := True;
      ReadAnImportOutLoud := 2;
    end;

    FS.Read(buf, 4);

    if (isOldExport) then
    begin
      { The true address is stored in the address we just read from }
      lastRomPosition := FS.Position;
      FS.Seek(romExplorer.RomToOffset(buf), soBeginning);
      FS.Read(buf, 4);
      FS.Seek(lastRomPosition, soBeginning);
    end;
  end
  else
    ReadAnImportOutLoud := 0;
end;

procedure TMainForm.ShowLinkBtnClick(Sender: TObject);
var
  Size, i, k, len: longint;
  buf, expnum, expdir: dword;
  Name, expnames: string;
  Relations: TStringList;
  implist: TStringList;
  lastRomPosition: qword;
  exptable, explist: array of string;
  isOldExport: boolean;
  dic: mDic;
begin

  ShowLinkBtn.Caption := 'Processing...';
  ShowLinkBtn.Enabled := False;

  LoadDumpBtn.Enabled := False;
  ExtractSelectedBtn.Enabled := False;
  ExtractAllBtn.Enabled := False;
  MakeIDCSelectedBtn.Enabled := False;
  MakeIDCAllBtn.Enabled := False;
  ConvertedToE32Btn.Enabled := False;

  Memo.Lines.Clear;

  Relations := TStringList.Create;
  Relations.Add('XIP linking for ' + StringGrid1.Rows[StringGrid1.Row][1]);
  Relations.Add(Format('Start 0x%s - end 0x%s',
    [StringGrid1.Rows[StringGrid1.Row][3],
    inttohex(StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][2]) +
    StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][3]), 8)]));
  Relations.Add('');
  // showmessage('pass 0');

  // FPS:=TMemoryStream.Create;
  // FS.Seek(0,0);
  // FPS.CopyFrom(FS, FS.Size);
  // FPS.Seek(0,0);

  FS.Seek(romExplorer.RomToOffset(StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][3])), 0);
  FS.Seek($3C, 1);
  FS.Read(expnum, 4);
  FS.Read(expdir, 4);

  SetLength(exptable, expnum);
  SetLength(explist, expnum);

  // explist := TStringList.Create;
  // explist.Sorted := true;
  implist := TStringList.Create;
  // implist.Sorted := true;

  if expnum > 0 then
  begin
    FS.Seek(romExplorer.RomToOffset(expdir), 0);
    for i := 1 to expnum do
    begin
      FS.Read(buf, 4);
      exptable[i - 1] := inttohex(buf, 8);
    end;

    // showmessage('pass 1');
    if expnum > 0 then
      for i := 1 to StringGrid1.RowCount - 1 do
      begin
        FS.Seek(romExplorer.RomToOffset(StrToInt('$' + StringGrid1.Rows[i][3])), 0);
        Size := StrToInt('$' + StringGrid1.Rows[i][2]);
        len := FS.Position + Size;
        Application.ProcessMessages;

        ShowLinkBtn.Caption :=
          Format('Processing [%d/%d] ...', [i, StringGrid1.RowCount - 1]);

        while (FS.Position < len) and (FS.Position < FS.Size) do
        begin
          // inc(len, 4);
          if ReadAnImportOutLoud(FS, buf) > 0 then
          begin
            // inc(len, 4);
            for k := 0 to expnum - 1 do
              if (buf <> 0) and (exptable[k] = inttohex(buf, 8)) and
                (Pos(StringGrid1.Rows[i][1], explist[k]) = 0) then
              begin
                explist[k] := explist[k] + ' ' + StringGrid1.Rows[i][1];
                if Pos(StringGrid1.Rows[i][1], expnames) = 0 then
                  expnames := expnames + StringGrid1.Rows[i][1] + ' ';
                break;
              end;
            // explist.Values[inttohex(buf, 8)] := explist.Values[inttohex(buf, 8)] + ' ' + StringGrid1.Rows[i][1];
          end;
        end;
      end;
  end;

  // showmessage('pass 2');

  FS.Seek(romExplorer.RomToOffset(StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][3])), 0);
  Size := StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][2]);
  len := FS.Position + Size + $78;

  // showmessage('pass 3');
  Size := 0;
  while (FS.Position < len) and (FS.Position < FS.Size) do
  begin
    { LDR PC, [PC, #-4] , basically jump stub }
    { In some case it's thumb with LDR R3, [PC, #0], address aligned by 4 }
    if ReadAnImportOutLoud(FS, buf) > 0 then
    begin
      if dicM.TryGetValue(buf, dic) then
        implist.Values[StringGrid1.Rows[dic[0]][1]] :=
          implist.Values[StringGrid1.Rows[dic[0]][1]] +
          Format('%4d:%s', [dic[1], inttohex(buf, 8)]) + ' ';
      Inc(Size);
    end;
  end;

  // FPS.Free;

  // showmessage('pass 4');
  Relations.Add(Format('File used %d times by: %s',
    [StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][4]), expnames]));
  for i := 0 to Length(exptable) - 1 do
    Relations.Add(Format('%4d 0x%s %s', [i + 1, exptable[i], explist[i]]));
  Relations.Add('');
  Relations.Add(Format('File imports %d functions from %d libraries:',
    [Size, implist.Count]));
  for Name in implist do
    Relations.Add('from ' + StringReplace(Name, '=', #$0d#$0a#$20#$20#$20#$20,
      [rfReplaceAll]));

  if ShowLogCBox.Checked then
  begin
    Memo.Lines := Relations;
    StringGrid1.Height := Max(0, StringGrid1.Height - Memo.Height);
    StringGrid1.Anchors := StringGrid1.Anchors - [akBottom];
    StringGrid1.TopRow := StringGrid1.Row;
    Memo.Visible := True;

    HideLogBtn.Visible := True;
    SaveLogBtn.Visible := True;
  end;

  Relations.SaveToFile(ExtractFilePath(OpenDialog.FileName) +
    StringReplace(StringGrid1.Rows[StringGrid1.Row][1] + '_LINKS_' +
    TimeToStr(now) + '.log', ':', '.', [rfReplaceAll]));

  LoadDumpBtn.Enabled := True;
  ExtractSelectedBtn.Enabled := True;
  ExtractAllBtn.Enabled := True;
  MakeIDCSelectedBtn.Enabled := True;
  MakeIDCAllBtn.Enabled := True;
  ConvertedToE32Btn.Enabled := True;

  ShowLinkBtn.Enabled := True;
  ShowLinkBtn.Caption := 'Done!';
  Delay(3000);
  ShowLinkBtn.Caption := 'Show links';

  Relations.Free;
  implist.Free;
  SetLength(explist, 0);
  SetLength(exptable, 0);

end;

procedure TMainForm.SaveLogBtnClick(Sender: TObject);
begin
  SaveDialog.FileName := 'aRomAT.log';
  if SaveDialog.Execute then
    Memo.Lines.SaveToFile(SaveDialog.FileName);
end;

procedure TMainForm.RemoveSelectionBtnClick(Sender: TObject);
var
  s: string;
begin
  for s in sgsel do
    StringGrid1.Cells[0, StrToInt(s)] := ' ';
  StringGrid1.Repaint;
  sgsel.Clear;
  CheckDSOBtn.Visible := False;
end;

procedure TMainForm.LoadDumpBtnClick(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    LoadDump(OpenDialog.FileName);
    ProcessExportsBtnClick(nil);
    CheckDSOBtnClick(nil);
    MakeDICBtnClick(nil);
    StringGrid1.SetFocus;
  end;
end;

procedure TMainForm.ExtractSelectedBtnClick(Sender: TObject);
var
  s: string;
begin
  SaveDialog.FileName := StringGrid1.Rows[StringGrid1.Row][1];
  if SaveDialog.Execute then
  begin
    if sgsel.Count = 0 then
      SaveFile(SaveDialog.FileName, StringGrid1.Row)
    else
      for s in sgsel do
        SaveFile(ExtractFilePath(SaveDialog.FileName) +
          StringGrid1.Rows[StrToInt(s)][1], StrToInt(s));

    MainForm.ExtractSelectedBtn.Caption := 'Done!';
    Delay(3000);
    MainForm.ExtractSelectedBtn.Caption := 'Extract selected';
  end;
end;

procedure TMainForm.CheckDSOBtnClick(Sender: TObject);
begin
  CheckDSOBtn.Enabled := False;
  if DirectoryExists(ExtractFilePath(Application.Exename) + 'dso') then
  begin
    CheckDSOBtn.Font.Color := clGreen;
    CheckDSOBtn.Kind := bkOk;
    CheckDSOBtn.Caption := 'Dso folder ready';
    CheckDSOBtn.Font.Style := [];
  end
  else
  begin
    CheckDSOBtn.Font.Color := clRed;
    CheckDSOBtn.Kind := bkNo;
    CheckDSOBtn.Caption := 'Please check dso!';
    CheckDSOBtn.Enabled := True;
    CheckDSOBtn.Font.Style := [fsBold];
  end;
end;

procedure TMainForm.MemoChange(Sender: TObject);
begin

end;

procedure TMainForm.ProcessExportsBtnClick(Sender: TObject);
var
  i, j, k: longint;
  expnum, expaddr, bufexp, dsosize, dsostart, exportLineTokenPos, exportNum: dword;
  exportFileStream: TFileStream;
  sDso: TStringList;
  fname, dname, exportTempName, exportTempLine: AnsiString;
  Temp: TBytes;
  b: byte;
  dic: mDic;
begin
  ProcessExportsBtn.Enabled := False;

  Application.ProcessMessages;
  for i := 1 to StringGrid1.RowCount - 1 do
  begin
    FS.Seek(romExplorer.RomToOffset($3C + StrToInt('$' + StringGrid1.Rows[i][3])), 0);
    FS.Read(expnum, 4);
    FS.Read(expaddr, 4);
    if expnum > 0 then
    begin
      fname := StringGrid1.Rows[i][1];
      dname := ExtractFilePath(Application.Exename) + 'dso\' +
        Copy(fname, 0, Length(fname) - 4);
      sDso := TStringList.Create;
      if FileExists(dname + '.dso') then
      begin
        dname := dname + '.dso';

        { Read DSO export lists }
        exportFileStream := TFileStream.Create(dname, fmOpenRead or fmShareDenyNone);
        exportFileStream.Seek($134, 0);
        exportFileStream.Read(dsostart, 4);
        exportFileStream.Read(dsosize, 4);
        exportFileStream.Seek(dsostart + 1, 0);
        SetLength(Temp, dsosize);
        exportFileStream.Read(Temp[0], dsosize);
        while Temp[Length(Temp) - 1] = 0 do
          SetLength(Temp, Length(Temp) - 1);
        for b in Temp do
          if b > 0 then
            exportTempName := exportTempName + chr(b)
          else
            exportTempName := exportTempName + #13#10;
        SetLength(Temp, 0);
        sDso.Text := exportTempName;
        exportTempName := '';
        sDso.Delete(sDso.Count - 1);
        sDso.Delete(sDso.Count - 1);

        exportFileStream.Free;
      end
      else if FileExists(dname + '.idt') then
      begin
        dname := dname + '.idt';

        { Try to read IDT exports }
        exportFileStream := TFileStream.Create(dname, fmOpenRead or fmShareDenyNone);
        while ReadLineAscii(exportFileStream, exportTempLine) do
        begin
          { Trim down spaces }
          while (Length(exportTempLine) > 0) and (exportTempLine[1] = ' ') do
            Delete(exportTempName, 1, 1);

          { Ignore the first export or comments }
          if (Length(exportTempLine) = 0) or (exportTempLine[1] = #13) or (exportTempLine[1] = ';') or
             (exportTempLine[1] = '0') then
             continue;

          { Ignore if the first characters are not number, we are expecting ordinal numbers }
          if not (exportTempLine[1] in ['0'..'9']) then
             continue;
          
          { Parse the numbers at the beginning }
          exportTempName := '';
          exportLineTokenPos := 1;

          while (exportTempLine[exportLineTokenPos] in ['0'..'9']) do
          begin
            exportTempName := exportTempName + exportTempLine[exportLineTokenPos];
            inc(exportLineTokenPos);
          end;

          exportNum := StrToInt(exportTempName);

          while (exportLineTokenPos <= Length(exportTempLine)) and (exportTempLine[exportLineTokenPos] = ' ') do
            inc(exportLineTokenPos);

          { We also want to skip the NAME= }
          if ((Length(exportTempLine) - exportLineTokenPos + 1) <= 5) then
            continue;

          exportTempName := Copy(exportTempLine, exportLineTokenPos, Length(exportTempLine) - exportLineTokenPos + 1);

          { Delete the newline }
          if (exportTempName[Length(exportTempName)] = #13) then
            Delete(exportTempName, Length(exportTempName), 1);

          sDso.Insert(exportNum - 1, exportTempName);
        end;
      end;
      FS.Seek(romExplorer.RomToOffset(expaddr), 0);
      for j := 1 to expnum do
      begin
        FS.Read(bufexp, 4);
        if bufexp <> 0 then
        begin
          dic[0] := i;
          dic[1] := j;
          dicM.AddOrSetValue(bufexp, dic);

          if bufexp = 0 then
            NamesArray.AddOrSetValue(
              { RomToOffset( } bufexp, StringGrid1.Rows[i][1] +
              '_absent_export_' + IntToStr(j))
          else if j < sDso.Count + 1 then
            NamesArray.AddOrSetValue( { RomToOffset( } bufexp, sDso[j - 1])
          else
            NamesArray.AddOrSetValue(
              { RomToOffset( } bufexp, StringGrid1.Rows[i][1] + '_' +
              IntToStr(j));
          Inc(k);
          if k = 100 then
          begin
            Application.ProcessMessages;
            k := 0;
          end;
        end;
      end;
      sDso.Free;
    end;
    StringGrid1.Rows[i][4] := inttohex(expnum, 8);
  end;

  ProcessExportsBtn.Font.Color := clGreen;
  ProcessExportsBtn.Kind := bkOk;
  ProcessExportsBtn.Caption := 'Exports ready';
  MakeIDCSelectedBtn.Enabled := True;
  ExtractAllBtn.Enabled := True;
  MakeIDCAllBtn.Enabled := True;
end;

procedure TMainForm.ShowLogInfo3LabelClick(Sender: TObject);
begin

end;

procedure MakeIDC(num: integer);
var
  Size, i, len: longint;
  buf, entry: dword;
  Name: string;
  importCodeType: byte;
  IDC: TStringList;
begin
  IDC := TStringList.Create;
  IDC.Add('#define UNLOADED_FILE   1');
  IDC.Add('#include <idc.idc>');
  IDC.Add('static main(void) {');
  FS.Seek(romExplorer.RomToOffset(StrToInt('$' + MainForm.StringGrid1.Rows[num][3])), 0);
  FS.Seek($10, 1);
  FS.Read(entry, 4);
  FS.Seek($64, 1);
  Size := StrToInt('$' + MainForm.StringGrid1.Rows[num][2]);
  len := FS.Position + Size;
  i := 0;
  importCodeType := 0;

  while (FS.Position < len) and (FS.Position < FS.Size) do
  begin
    importCodeType := ReadAnImportOutLoud(FS, buf);

    if (importCodeType > 0)  then
    begin
      if NamesArray.TryGetValue( { RomToOffset( } buf, Name) then
      begin
        if Copy(Name, 1, 1) = '"' then
          Name := StringReplace(Name, '"', '', [rfReplaceAll]);

        { Assign offset to subtract to get import address }
        if (importCodeType = 1) then importCodeType := 8
        else importCodeType := 12;

        IDC.Add(Format('MakeCode(0x%s);', [inttohex(romExplorer.OffsetToRom(FS.Position - importCodeType)
          { RomToOffsetBase(entry) }, 8)]));
        IDC.Add(Format('MakeName(0x%s,"%s");',
          [inttohex(romExplorer.OffsetToRom(FS.Position - importCodeType)
          { RomToOffsetBase(entry) }, 8), Name]));
      end;
    end;
    Inc(i);
    if i = 200 then
    begin
      Application.ProcessMessages;
      i := 0;
    end;
  end;
  if StrToInt('$' + MainForm.StringGrid1.Rows[num][4]) > 0 then
  begin
    FS.Seek(romExplorer.RomToOffset(StrToInt('$' + MainForm.StringGrid1.Rows[num][3])), 0);
    FS.Seek($40, 1);
    FS.Read(buf, 4);
    FS.Seek(romExplorer.RomToOffset(buf), 0);
    for i := 1 to StrToInt('$' + MainForm.StringGrid1.Rows[num][4]) do
    begin
      FS.Read(buf, 4);
      if buf = 0 then
        IDC.Add(Format('RenameEntryPoint(%d,"%s");',
          [i, MainForm.StringGrid1.Rows[num][1] + '_absent_export_' +
          IntToStr(i)]))
      else if NamesArray.TryGetValue( { RomToOffset( } buf, Name) then
        if (Name[1] = '"') then
          IDC.Add(Format('RenameEntryPoint(%d,%s);', [i, Name]))
        else

          IDC.Add(Format('RenameEntryPoint(%d,"%s");', [i, Name]))
      else
        IDC.Add(Format('RenameEntryPoint(%d,"%s");',
          [i, MainForm.StringGrid1.Rows[num][1] + '_' + IntToStr(i)]));
    end;
  end;
  IDC.Add('}');
  IDC.SaveToFile(MainForm.SaveDialog.FileName);

  IDC.Free;
end;

procedure TMainForm.MakeIDCSelectedBtnClick(Sender: TObject);
var
  s: string;
begin
  SaveDialog.FileName := StringGrid1.Rows[StringGrid1.Row][1] + '.idc';
  if SaveDialog.Execute then
  begin
    if sgsel.Count = 0 then
      MakeIDC(StringGrid1.Row)
    else
      for s in sgsel do
      begin
        SaveDialog.FileName :=
          ExtractFilePath(SaveDialog.FileName) + StringGrid1.Rows[StrToInt(s)]
          [1] + '.idc';
        MakeIDC(StrToInt(s));
      end;
    MainForm.MakeIDCSelectedBtn.Caption := 'Done!';
    Delay(3000);
    MainForm.MakeIDCSelectedBtn.Caption := 'Make idc for selected';
  end;
end;

procedure TMainForm.BitBtn6Click(Sender: TObject);
var
  fname: string;
  i: integer;
begin
  SaveDialog.FileName := StringGrid1.Rows[1][1];
  if SaveDialog.Execute then
  begin
    fname := ExtractFilePath(SaveDialog.FileName);
    ExtractAllBtn.Enabled := False;
    ExtractAllBtn.Caption := 'Processing...';
    for i := 1 to StringGrid1.RowCount - 1 do
    begin
      if i mod 100 = 0 then
        ExtractAllBtn.Caption :=
          Format('Processing [%d/%d] ...', [i, StringGrid1.RowCount - 1]);
      Application.ProcessMessages;
      SaveFile(fname + StringGrid1.Rows[i][1], i);
    end;
    ExtractAllBtn.Enabled := True;
    ExtractAllBtn.Caption := 'Done!';
    Delay(3000);
    ExtractAllBtn.Caption := 'Extract all';
  end;
end;

procedure TMainForm.MakeIDCAllBtnClick(Sender: TObject);
var
  fname: string;
  i: integer;
begin
  SaveDialog.FileName := StringGrid1.Rows[1][1] + '.idc';
  if SaveDialog.Execute then
  begin
    MakeIDCAllBtn.Enabled := False;
    MakeIDCAllBtn.Caption := 'Processing...';
    fname := ExtractFilePath(SaveDialog.FileName);
    for i := 1 to StringGrid1.RowCount - 1 do
    begin
      if i mod 100 = 0 then
        MakeIDCAllBtn.Caption :=
          Format('Processing [%d/%d] ...', [i, StringGrid1.RowCount - 1]);
      Application.ProcessMessages;
      SaveDialog.FileName := fname + StringGrid1.Rows[i][1] + '.idc';
      MakeIDC(i);
    end;

    MakeIDCAllBtn.Enabled := True;
    MakeIDCAllBtn.Caption := 'Done!';
    Delay(3000);
    MakeIDCAllBtn.Caption := 'Make idc for all';
  end;
end;

procedure TMainForm.MakeDICBtnClick(Sender: TObject);
var
  i: integer;
  uid, startad, modulever, codesize, datasize, filesize: dword;
  arr: tDic;
begin

  Application.ProcessMessages;
  for i := 1 to StringGrid1.RowCount - 1 do
  begin
    FS.Seek(romExplorer.RomToOffset(StrToInt('$' + StringGrid1.Rows[i][3])), 0);
    FS.Seek(8, 1);
    FS.Read(uid, 4);
    FS.Seek(8, 1);
    FS.Read(startad, 4);
    FS.Seek(4, 1);
    FS.Read(codesize, 4);
    FS.Seek(4, 1);
    FS.Read(datasize, 4);
    filesize := codesize + datasize + $78;
    FS.Seek(72, 1);
    FS.Read(modulever, 4);

    arr[0] := StringGrid1.Rows[i][1];
    arr[1] := IntToStr(startad);
    arr[2] := IntToStr(startad + filesize);
    arr[3] := LowerCase(inttohex(modulever, 8));
    arr[4] := LowerCase(inttohex(uid, 8));
    arr[5] := StringGrid1.Rows[i][4];
    dicT.AddOrSetValue(i, arr);
  end;

  MakeDICBtn.Kind := bkOk;
  MakeDICBtn.Caption := 'Infodic ready';
  MakeDICBtn.Enabled := False;
  ConvertedToE32Btn.Enabled := True;
  ShowLinkBtn.Enabled := True;
  // SaveSeperateCBox.Visible := True;

  ShowLogCBox.Visible := True;
  ShowLogInfoLabel.Visible := True;
end;

function command_chk(addr: dword): boolean;
begin
  Result := False;
  case addr and $FFFF of
    $B0B0:
      Result := True;
    $ABB0:
      Result := True;
    $AAB0:
      Result := True;
  end;
  case addr of
    $80068400:
      Result := True;
    $83A010FF:
      Result := True;
  end;
end;

procedure Sort_Shell(var a: array of longint);
var
  bis, i, j, k: longint;
  h: word;
begin
  bis := High(a);
  k := bis shr 1; // div 2
  while k > 0 do
  begin
    for i := 0 to bis - k do
    begin
      j := i;
      while (j >= 0) and (a[j] > a[j + k]) do
      begin
        h := a[j];
        a[j] := a[j + k];
        a[j + k] := h;
        if j > k then
          Dec(j, k)
        else
          j := 0;
      end; // {end while]
    end; // { end for}
    k := k shr 1; // div 2
  end; // {end while}

end;

procedure Sort_Bubble(var a: array of dword);
var
  changed: boolean;
  i: longint;
  buf: dword;
begin
  repeat
    changed := False;
    for i := 0 to Length(a) - 2 do
      if a[i] < a[i + 1] then
      begin
        buf := a[i];
        a[i] := a[i + 1];
        a[i + 1] := buf;
        changed := True;
      end;
  until not changed;
end;

procedure TMainForm.ConvertedToE32BtnClick(Sender: TObject);
var
  Knull: dword;

  fdata: tDic;
  ad_ofset, start_ad, end_ad, file_size, export_num: dword;

  uid1, uid2, uid3, uidcrc, xEntryPoint, xCodeAddress, iEntryPoint,
  iCodeBase, iDataBase, xDataAddress, iDataOffset, xCodeSize, iTextSize,
  xDataSize, xBssSize, iHeapSizeMin, iHeapSizeMax, iStackSize,
  xDllRefTable, iExportDirCount, xExportDir, iExportDirOffset, iSecureId,
  iVendorId, iSecurityCapsHi, iSecurityCapsLo, iToolsVersion, xFlags,
  iFlags, xPriority, iPriority, xDataBssLinearBase, iNextExtension,
  iHardwareVariant, iTotalDataSize, iModuleVersion, xExceptionDescriptor,
  iExceptionDescriptor, iExportDesc, iSpare2, xDllRef: dword;

  iFlag0, iFlag1, iFlag2, iFlag3: byte;

  Add, add_mod, fno, ad_minold, ad_maxold, ad_size: dword;
  fp, fp2, rlocbase, datarlocbase, fp0, i, k, last_rlocbase, last_datarlocbase: longint;
  fname, FileName: string;

  F: TMemoryStream;
  tempword: words;
  tempDicM: mDic;
  tempDicT: tDic;
  tempdword: dwords;

  dummy, DRTno: integer;
  xtest: dword;

  codesec, importsec, relocsec, datarelocsec, header: TMemoryStream;
  outfile: TFileStream;

  importnum, importsize, n00, addnum: dword;
  xImportSize, iImportOffset, iDllRefTableCount: dword;
  adddata: array of dwords;
  import: dwords;
  fndata: array of ansistring;

  relocsize, relocnum, relocn, relocs, xCodeRelocSize, iCodeRelocOffset: dword;
  relocbase, datarelocbase: longint;
  relocdata, datarelocdata: words;

  datarelocsize, datarelocnum, datarelocn, datarelocs, xDataRelocSize,
  iDataRelocOffset, iUncompressedSize: dword;

  CodeRelocSort, DataRelocSort: array of integer;
  ImpSort: array of dword;
  iHeaderCrc: dword;

  ansiheader: ansistring;
  bytesheader: TBytes;
  onebyte: byte;
  headercrc, signature, timelo, timehi, iCodeOffset: dword;

  code_relocs, data_relocs, last_code_relocs, last_data_relocs: longint;
  code_relocsize, code_relocs_size, data_relocsize, data_relocs_size: dword;
  code_reloc_savepos, data_reloc_savepos: int64;
  NullWord, code_reloc, data_reloc: word;

  testboo: word;
  s: string;

  log, fnames: TStringList;
begin
  FileName := ExtractFilePath(OpenDialog.FileName);

  if (sgsel.Count > 0) and (Sender <> nil) then
  begin
    for s in sgsel do
    begin
      StringGrid1.Row := StrToInt(s);
      ConvertedToE32BtnClick(nil);
    end;

    ConvertedToE32Btn.Caption := 'Done!';
    Delay(3000);
    ConvertedToE32Btn.Caption := 'Convert selected to EPOC';

    exit;
  end;

  ConvertedToE32Btn.Caption := 'Converting...';
  ConvertedToE32Btn.Enabled := False;

  LoadDumpBtn.Enabled := False;
  ExtractSelectedBtn.Enabled := False;
  ExtractAllBtn.Enabled := False;
  MakeIDCSelectedBtn.Enabled := False;
  MakeIDCAllBtn.Enabled := False;
  ShowLinkBtn.Enabled := False;

  Memo.Lines.Clear;
  fnames := TStringList.Create;
  log := TStringList.Create;

  dicRloc := TDictionary<longint, words>.Create;
  dicDataRloc := TDictionary<longint, words>.Create;
  dicImp := TDictionary<dword, dwords>.Create;

  signature := $434F5045;
  iHeaderCrc := $C90FDAA2;
  Knull := $00000000;
  NullWord := $0000;

  timelo := $6f526100;
  timehi := $0054416d;
  iCodeOffset := $0000009C;
  dicT.TryGetValue(StringGrid1.Row, fdata);

  ad_ofset := strtoint64(fdata[1]);
  start_ad := strtoint64(fdata[1]);
  end_ad := strtoint64(fdata[2]);
  file_size := end_ad - start_ad;
  export_num := strtoint64('$' + fdata[5]);

  log.Add('XIP modify of ' + fdata[0] + ' to E32image.');
  log.Add(Format('** start 0x%s -> end 0x%s', [inttohex(start_ad, 8),
    inttohex(end_ad - $78, 8)]));

  codesec := TMemoryStream.Create;

  F := TMemoryStream.Create;
  FS.Seek($8C, 0);
  FS.Read(ad_minold, 4);
  FS.Seek($F4, 0);
  FS.Read(ad_size, 4);
  ad_maxold := ad_minold + ad_size;
  FS.Seek(romExplorer.RomToOffset(StrToInt('$' + StringGrid1.Rows[StringGrid1.Row][3])),
    0);
  F.CopyFrom(FS, file_size + $78);
  F.Seek(0, 0);
  // **read ROMimage header info**
  F.Read(uid1, 4);
  F.Read(uid2, 4);
  F.Read(uid3, 4);
  F.Read(uidcrc, 4);
  F.Read(xEntryPoint, 4);
  F.Read(xCodeAddress, 4);
  iEntryPoint := xEntryPoint - xCodeAddress;
  iCodeBase := $8000;
  F.Read(xDataAddress, 4);
  if xDataAddress <> 0 then
    log.Add(Format('** DataAddress NOT 0x00!! %s', [inttohex(xDataAddress, 8)]));
  iDataOffset := xDataAddress - xCodeAddress + $9C;
  F.Read(xCodeSize, 4);
  F.Read(iTextSize, 4);
  F.Read(xDataSize, 4);
  if xDataSize <> 0 then
  begin
    iDataBase := $400000;
    iDataOffset := xDataAddress - xCodeAddress + $9C;
    log.Add(Format('** DataSize NOT 0x00!! %s', [inttohex(xDataSize, 8)]));
  end
  else
  begin
    iDataBase := dword(0);
    iDataOffset := dword(0);
  end;
  F.Read(xBssSize, 4);
  if xBssSize <> 0 then
    log.Add(Format('** BssSize NOT 0x00!! %s', [inttohex(xBssSize, 8)]));
  F.Read(iHeapSizeMin, 4);
  F.Read(iHeapSizeMax, 4);
  F.Read(iStackSize, 4);
  F.Read(xDllRefTable, 4);
  F.Read(iExportDirCount, 4);
  F.Read(xExportDir, 4);
  iExportDirOffset := xExportDir - xCodeAddress + $9C;
  F.Read(iSecureId, 4);
  F.Read(iVendorId, 4);
  F.Read(iSecurityCapsHi, 4);
  F.Read(iSecurityCapsLo, 4);
  F.Read(iToolsVersion, 4);
  // F.Read(xFlags, 4);
  // iFlags := xFlags + $12000000;
  F.Read(iFlag0, 1);
  F.Read(iFlag1, 1);
  // iFlag1 := $02;
  F.Read(iFlag2, 1);
  iFlag2 := $00;
  F.Read(iFlag3, 1);
  iFlag3 := $12;
  // showmessage(inttohex( xFlags ,8));
  // showmessage(inttohex( iFlags ,8));
  F.Read(xPriority, 4);
  iPriority := xPriority + $20000000;
  F.Read(xDataBssLinearBase, 4);
  F.Read(iNextExtension, 4);
  F.Read(iHardwareVariant, 4);
  F.Read(iTotalDataSize, 4);
  F.Read(iModuleVersion, 4);
  F.Read(xExceptionDescriptor, 4);
  if xExceptionDescriptor > xCodeAddress then
    iExceptionDescriptor := xExceptionDescriptor - xCodeAddress + 1
  else
    iExceptionDescriptor := xExceptionDescriptor;
  iExportDesc := dword(0);
  iSpare2 := dword(0);
  // **modify CodeSection & DataSection**
  log.Add('FileTop+:CodeTop+:Replacement       :Comment');
  fp := $78;
  fp2 := $78;
  rlocbase := 0;
  datarlocbase := 0;

  relocsec := TMemoryStream.Create;
  relocsec.Write(Knull, 4);
  relocsec.Write(Knull, 4);
  relocsec.Write(rlocbase, 4);
  code_reloc_savepos := relocsec.Position;
  relocsec.Write(Knull, 4);

  datarelocsec := TMemoryStream.Create;
  // datarelocsec.SetSize(0);

  datarelocsec.Write(Knull, 4);
  datarelocsec.Write(Knull, 4);
  datarelocsec.Write(rlocbase, 4);
  data_reloc_savepos := datarelocsec.Position;
  datarelocsec.Write(Knull, 4);

  while fp < (xCodeSize + xDataSize + $78) do
  begin
    F.Seek(fp, 0);
    F.Read(Add, 4);
    fp0 := fp - $78;
    if fp0 >= (rlocbase + $1000) then
      rlocbase := rlocbase + $1000;
    if fp0 >= (datarlocbase + $1000 + xCodeSize) then
      datarlocbase := datarlocbase + $1000;
    if (Add >= start_ad) and (Add <= end_ad) then
    begin
      if fp0 < xCodeSize then
      begin
        add_mod := Add - ad_ofset + iCodeBase;
        if (rlocbase <> last_rlocbase) and (last_code_relocs <> code_relocs) then
        begin
          if relocsec.Size mod 4 <> 0 then
            relocsec.Write(NullWord, 2);
          relocsec.Seek(code_reloc_savepos, 0);
          code_relocsize := relocsec.Size - code_reloc_savepos + 4;
          relocsec.Write(code_relocsize, 4);
          relocsec.Seek(0, 2);

          if code_relocs = 0 then
            relocsec.Seek(-8, 1);

          relocsec.Write(rlocbase, 4);
          code_reloc_savepos := relocsec.Position;
          relocsec.Write(Knull, 4);
          last_rlocbase := rlocbase;
          last_code_relocs := code_relocs;
        end;
        Inc(code_relocs);
        code_reloc := fp0 - rlocbase + $1000;
        relocsec.Write(code_reloc, 2);
      end { if fp0 < xCodeSize }
      else
      begin { if fp0 >= xCodeSize }
        add_mod := Add - ad_ofset + iCodeBase;
        if (datarlocbase <> last_datarlocbase) or
          (last_data_relocs <> data_relocs) then
        begin
          if datarelocsec.Size mod 4 <> 0 then
            datarelocsec.Write(NullWord, 2);
          datarelocsec.Seek(data_reloc_savepos, 0);
          data_relocsize := datarelocsec.Size - data_reloc_savepos + 4;
          datarelocsec.Write(data_relocsize, 4);
          datarelocsec.Seek(0, 2);

          if data_relocs = 0 then
            datarelocsec.Seek(-8, 1);

          datarelocsec.Write(datarlocbase, 4);
          data_reloc_savepos := datarelocsec.Position;
          datarelocsec.Write(Knull, 4);
          last_datarlocbase := datarlocbase;
          last_data_relocs := data_relocs;
        end;
        Inc(data_relocs);
        data_reloc := fp0 - datarlocbase + $1000 - xCodeSize;
        datarelocsec.Write(data_reloc, 2);
      end; { if fp0 >= xCodeSize }
      log.Add(Format('%s:%s:%s->%s:Change Addr', [inttohex(fp, 8),
        inttohex(fp0, 8), inttohex(Add, 8), inttohex(add_mod, 8)]));
    end { if (add >= start_ad) and (add <= end_ad) }
    else if (fp0 >= xCodeSize) and (Add >= xDataBssLinearBase) and
      (Add <= xDataBssLinearBase + xDataSize + xBssSize) then
    begin
      add_mod := Add - xDataBssLinearBase + iDataBase;
      if (datarlocbase <> last_datarlocbase) or
        (last_data_relocs <> data_relocs) then
      begin
        if datarelocsec.Size mod 4 <> 0 then
          datarelocsec.Write(NullWord, 2);
        datarelocsec.Seek(data_reloc_savepos, 0);
        data_relocsize := datarelocsec.Size - data_reloc_savepos + 4;
        datarelocsec.Write(data_relocsize, 4);
        datarelocsec.Seek(0, 2);

        if data_relocs = 0 then
          datarelocsec.Seek(-8, 1);

        datarelocsec.Write(datarlocbase, 4);
        data_reloc_savepos := datarelocsec.Position;
        datarelocsec.Write(Knull, 4);
        last_datarlocbase := datarlocbase;
        last_data_relocs := data_relocs;
      end;
      Inc(data_relocs);
      data_reloc := fp0 - datarlocbase + $2000 - xCodeSize;
      datarelocsec.Write(data_reloc, 2);
      log.Add(Format('%s:%s:%s->%s:Change Addr', [inttohex(fp, 8),
        inttohex(fp0, 8), inttohex(Add, 8), inttohex(add_mod, 8)]));
    end { if (fp0 >= xCodeSize) and (add >= xDataBssLinearBase) }
    else if dicM.ContainsKey(Add) then
    begin
      dicM.TryGetValue(Add, tempDicM);
      fno := tempDicM[0];
      dicT.TryGetValue(fno, tempDicT);
      fname := tempDicT[0];
      if (not command_chk(Add)) then
      begin
        add_mod := tempDicM[1];
        if dicImp.ContainsKey(fno) then
        begin
          dicImp.TryGetValue(fno, tempdword);
          SetLength(tempdword, Length(tempdword) + 1);
          tempdword[Length(tempdword) - 1] := fp0;
          dicImp.AddOrSetValue(fno, tempdword);
        end
        else
        begin
          SetLength(tempdword, 1);
          tempdword[0] := fp0;
          dicImp.AddOrSetValue(fno, tempdword);
        end; { if dicImp.ContainsKey(fno) }
        log.Add(Format('%s:%s:%s->%s:Change Port %s %d',
          [inttohex(fp, 8), inttohex(fp0, 8), inttohex(Add, 8),
          inttohex(add_mod, 8), fname, add_mod]));
        // if fnames.IndexOf(fname)<0 then
        // fnames.Add(fname);
      end { if not command_chk(add) }
      else
      begin { if command_chk(add) }
        add_mod := Add;
        log.Add(Format('%s:%s:%s Not change(SamePort %s %d)',
          [inttohex(fp, 8), inttohex(fp0, 8), inttohex(Add, 8),
          fname, tempDicM[1]]));
      end; { if command_chk(add) }
    end { if dicM.ContainsKey(add) }
    else if dicM.ContainsKey(Add - 8) then
    begin
      dicM.TryGetValue(Add - 8, tempDicM);
      fno := tempDicM[0];
      dicT.TryGetValue(fno, tempDicT);
      fname := tempDicT[0];
      // F.Seek(2, 1);
      // F.Read(testboo, 2);
      // F.Seek(-4, 1);
      if (not command_chk(Add))
      { or ((testboo <> $7fff) and (testboo <> $7ffe)) } then
      begin
        add_mod := tempDicM[1] + $80000;
        if dicImp.ContainsKey(fno) then
        begin
          dicImp.TryGetValue(fno, tempdword);
          SetLength(tempdword, Length(tempdword) + 1);
          tempdword[Length(tempdword) - 1] := fp0;
          dicImp.AddOrSetValue(fno, tempdword);
        end
        else
        begin
          SetLength(tempdword, 1);
          tempdword[0] := fp0;
          dicImp.AddOrSetValue(fno, tempdword);
        end; { if dicImp.ContainsKey(fno) }
        log.Add(Format('%s:%s:%s->%s:Change Port(offset by 8) %s %d',
          [inttohex(fp, 8), inttohex(fp0, 8), inttohex(Add, 8),
          inttohex(add_mod, 8), fname, tempDicM[1]]));
        // if fnames.IndexOf(fname)<0 then
        // fnames.Add(fname);
      end { if not command_chk(add) }
      else
      begin { if command_chk(add) }
        add_mod := Add;
        log.Add(Format('%s:%s:%s Not change(SamePort %s %d)',
          [inttohex(fp, 8), inttohex(fp0, 8), inttohex(Add, 8),
          fname, tempDicM[1]]));
      end; { if command_chk(add) }
    end { if dicM.ContainsKey(add-8) }
    else
    begin
      add_mod := Add;
      if (Add >= ad_minold) and (Add <= ad_maxold) and (not command_chk(Add)) then
        log.Add(Format('%s:%s:%s Not change(Need check)',
          [inttohex(fp, 8), inttohex(fp0, 8), inttohex(Add, 8)]));
    end;
    codesec.Write(add_mod, 4);
    fp := fp + 4;
    fp2 := fp2 + 4;
    if fp2 > 256 then
    begin
      Application.ProcessMessages;
      fp2 := 0;
    end;
  end; { while fp < (xCodeSize = xDataSize + $78) }

  // **print out iDllRefTable info
  if xDllRefTable > 0 then
  begin
    F.Seek(2, 1);
    F.Read(DRTno, 2);
    // Memo.Lines.Add(Format('**DllRefTable info : count = %d', [DRTno]));    //PrintOut Disabled
    for i := 1 to DRTno do
    begin
      F.Read(xDllRef, 4);
      // Memo.Lines.Add(Format('   %08x', [xDllRef]));
    end;
  end;
  F.Free;

    { log.Add(Format('** Image using %d ROM libraries:', [fnames.Count]));

      for fname in fnames do
      log.Add(fname); }

  fnames.Free;

  // **rebuild ImportSection**
  importnum := 0;
  importsize := 4;
  for fno in dicImp.Keys do
  begin
    SetLength(ImpSort, Length(ImpSort) + 1);
    ImpSort[Length(ImpSort) - 1] := fno;
  end;
  Sort_Bubble(ImpSort);
  for fno in ImpSort do
  begin
    addnum := Length(dicImp[fno]);
    importsize := importsize + (addnum + 2) * 4;
    SetLength(import, addnum + 1);
    import[0] := addnum;
    for i := 0 to addnum - 1 do
      import[i + 1] := dicImp[fno][i];

    SetLength(adddata, Length(adddata) + 1);
    adddata[Length(adddata) - 1] := import;

    SetLength(fndata, Length(fndata) + 1);
    fndata[Length(fndata) - 1] :=
      Copy(dicT[fno][0], 1, Length(dicT[fno][0]) - 4) + '{' + dicT[fno][3] + '}';
    if dicT[fno][4] <> '00000000' then
      fndata[Length(fndata) - 1] :=
        fndata[Length(fndata) - 1] + '[' + dicT[fno][4] + ']';
    fndata[Length(fndata) - 1] :=
      fndata[Length(fndata) - 1] + ExtractFileExt(dicT[fno][0]) + chr(0);
    Inc(importnum);
  end;
  iDllRefTableCount := importnum;
  importsec := TMemoryStream.Create;
  importsec.Write(Knull, 4);
  for i := 0 to importnum - 1 do
  begin
    importsec.Write(importsize, 4);
    for k := 0 to Length(adddata[i]) - 1 do
      importsec.Write(adddata[i][k], 4);
    importsize := importsize + Length(fndata[i]);
  end;
  n00 := importsize mod 4;
  xImportSize := importsize;
  if n00 <> 0 then
  begin
    n00 := 4 - n00;
    xImportSize := xImportSize + n00;
    for i := 1 to n00 do
      fndata[Length(fndata) - 1] := fndata[Length(fndata) - 1] + chr(0);
  end;
  for i := 0 to Length(fndata) - 1 do
    importsec.Write(fndata[i][1], Length(fndata[i]));
  importsec.Seek(0, 0);
  importsec.Write(importsize, 4);
  iImportOffset := xCodeSize + xDataSize + $9C;

  if code_relocs = 0 then
  begin
    relocsec.SetSize(0);
    relocsec.Clear;
    xCodeRelocSize := 0;
    iCodeRelocOffset := dword(0);
  end
  else
  begin
    if (rlocbase <> last_rlocbase) or (last_code_relocs <> code_relocs) then
    begin
      if relocsec.Size mod 4 <> 0 then
        relocsec.Write(NullWord, 2);
      relocsec.Seek(code_reloc_savepos, 0);
      code_relocsize := relocsec.Size - code_reloc_savepos + 4;
      relocsec.Write(code_relocsize, 4);
    end;

    relocsec.Seek(0, 0);
    code_relocs_size := relocsec.Size - 8;
    relocsec.Write(code_relocs_size, 4);
    relocsec.Write(code_relocs, 4);

    xCodeRelocSize := relocsec.Size;
    iCodeRelocOffset := xCodeSize + xDataSize + xImportSize + $9C;
  end;

  if data_relocs = 0 then
  begin
    datarelocsec.SetSize(0);
    datarelocsec.Clear;
    xDataRelocSize := 0;
    iDataRelocOffset := dword(0);
  end
  else
  begin
    if (datarlocbase <> last_datarlocbase) or (last_data_relocs <> data_relocs) then
    begin
      if datarelocsec.Size mod 4 <> 0 then
        datarelocsec.Write(NullWord, 2);
      datarelocsec.Seek(data_reloc_savepos, 0);
      data_relocsize := datarelocsec.Size - data_reloc_savepos + 4;
      datarelocsec.Write(data_relocsize, 4);
    end;

    datarelocsec.Seek(0, 0);
    data_relocs_size := datarelocsec.Size - 8;
    datarelocsec.Write(data_relocs_size, 4);
    datarelocsec.Write(data_relocs, 4);

    xDataRelocSize := datarelocsec.Size;
    iDataRelocOffset := xCodeSize + xDataSize + xImportSize + xCodeRelocSize + $9C;
  end;

  iUncompressedSize := xCodeSize + xDataSize + xImportSize +
    xCodeRelocSize + xDataRelocSize;
  header := TMemoryStream.Create;
  header.Write(uid1, 4);
  header.Write(uid2, 4);
  header.Write(uid3, 4);
  header.Write(uidcrc, 4);
  header.Write(signature, 4);
  header.Write(iHeaderCrc, 4);
  header.Write(iModuleVersion, 4);
  header.Write(Knull, 4);
  header.Write(iToolsVersion, 4);
  header.Write(timelo, 4);
  header.Write(timehi, 4);
  header.Write(iFlag0, 1);
  header.Write(iFlag1, 1);
  header.Write(iFlag2, 1);
  header.Write(iFlag3, 1);
  header.Write(xCodeSize, 4);
  header.Write(xDataSize, 4);
  header.Write(iHeapSizeMin, 4);
  header.Write(iHeapSizeMax, 4);
  header.Write(iStackSize, 4);
  header.Write(xBssSize, 4);
  header.Write(iEntryPoint, 4);
  header.Write(iCodeBase, 4);
  header.Write(iDataBase, 4);
  header.Write(iDllRefTableCount, 4);
  header.Write(iExportDirOffset, 4);
  header.Write(iExportDirCount, 4);
  header.Write(iTextSize, 4);
  header.Write(iCodeOffset, 4);
  header.Write(iDataOffset, 4);
  header.Write(iImportOffset, 4);
  header.Write(iCodeRelocOffset, 4);
  header.Write(iDataRelocOffset, 4);
  header.Write(iPriority, 4);
  header.Write(iUncompressedSize, 4);
  header.Write(iSecureId, 4);
  header.Write(iVendorId, 4);
  header.Write(iSecurityCapsHi, 4);
  header.Write(iSecurityCapsLo, 4);
  header.Write(iExceptionDescriptor, 4);
  header.Write(iSpare2, 4);
  header.Write(iExportDesc, 4);
  header.Seek(0, 0);
  SetLength(bytesheader, $9C);
  header.Read(bytesheader[0], $9C);
  headercrc := CRC32(0, bytesheader, $9C);
  header.Seek($14, 0);
  header.Write(headercrc, 4);
  header.Seek(0, 0);
  codesec.Seek(0, 0);
  importsec.Seek(0, 0);
  relocsec.Seek(0, 0);
  datarelocsec.Seek(0, 0);

  if SaveSeperateCBox.Checked then
  begin
    header.SaveToFile(FileName + StringGrid1.Rows[StringGrid1.Row][1] + '.header');
    codesec.SaveToFile(FileName + StringGrid1.Rows[StringGrid1.Row][1] +
      '.codesec');
    importsec.SaveToFile(FileName + StringGrid1.Rows[StringGrid1.Row][1] +
      '.importsec');
    relocsec.SaveToFile(FileName + StringGrid1.Rows[StringGrid1.Row][1] +
      '.relocsec');
    datarelocsec.SaveToFile(FileName + StringGrid1.Rows[StringGrid1.Row][1] +
      '.datarelocsec');
  end;
  outfile := TFileStream.Create(FileName + StringGrid1.Rows[StringGrid1.Row][1] +
    '.epoc', fmCreate or fmOpenWrite);
  outfile.CopyFrom(header, header.Size);
  outfile.CopyFrom(codesec, codesec.Size);
  outfile.CopyFrom(importsec, importsec.Size);
  outfile.CopyFrom(relocsec, relocsec.Size);
  outfile.CopyFrom(datarelocsec, datarelocsec.Size);
  outfile.Free;

  log.SaveToFile(FileName + StringReplace(
    StringGrid1.Rows[StringGrid1.Row][1] + '_XIP2EPOC_' + TimeToStr(now) +
    '.log', ':', '.', [rfReplaceAll]));

  if (ShowLogCBox.Checked) and (sgsel.Count = 0) then
  begin
    Memo.Lines := log;

    StringGrid1.Height := Max(0, StringGrid1.Height - Memo.Height);
    StringGrid1.Anchors := StringGrid1.Anchors - [akBottom];
    StringGrid1.TopRow := StringGrid1.Row;
    Memo.Visible := True;

    HideLogBtn.Visible := True;
    SaveLogBtn.Visible := True;
  end;

  log.Free;

  datarelocsec.Free;
  relocsec.Free;
  importsec.Free;
  codesec.Free;
  header.Free;

  dicRloc.Free;
  dicDataRloc.Free;
  dicImp.Free;

  LoadDumpBtn.Enabled := True;
  ExtractSelectedBtn.Enabled := True;
  ExtractAllBtn.Enabled := True;
  MakeIDCSelectedBtn.Enabled := True;
  MakeIDCAllBtn.Enabled := True;
  ShowLinkBtn.Enabled := True;

  ConvertedToE32Btn.Enabled := True;
  if sgsel.Count = 0 then
  begin
    ConvertedToE32Btn.Caption := 'Done!';
    Delay(3000);
    ConvertedToE32Btn.Caption := 'Convert selected to EPOC';
  end;
end;

procedure sgFindText(Grid: TStringGrid; const Text: string; FindOptions: TFindOptions);
var
  What, Where: string;
  i: integer;
begin
  What := AnsiLowerCase(Text);
  with Grid do
    for i := 1 to RowCount - 1 do
    begin
      Where := Cells[NAME_COLUMN, i];
      if What = '' then
        Row := 1
      else if Pos(What, Where) = 1 then
      begin
        Row := i;
        TopRow := i;
        break;
      end;
    end; { with }
end;

procedure TMainForm.ExtractAllBtnClick(Sender: TObject);
var
  addrToSearch, crrSize, crrAddr, i: dword;
begin
  if (length(SearchBoxEdit.Text) > 0) and (SearchBoxEdit.Text[1] in ['0'..'9']) then
  begin
    addrToSearch := 0;

    try
      SearchBoxEdit.Text := Trim(SearchBoxEdit.Text);

      if (length(SearchBoxEdit.Text) > 1) then
      begin
        if (SearchBoxEdit.Text[2] in ['x', 'X']) then
          { HEX HEX HEX }
          addrToSearch :=
            Hex2Dec(Copy(SearchBoxEdit.Text, 3, length(
            SearchBoxEdit.Text) - 2))
        else
          addrToSearch := StrToInt(SearchBoxEdit.Text);
      end
      else
        { Directly convert to number }
        addrToSearch := StrToInt(SearchBoxEdit.Text);
    except
      on E: EConvertError do
        addrToSearch := 0;
    end;

    if (addrToSearch = 0) then
      exit;

    { Search across the grid }
    with StringGrid1 do
      for i := 2 to RowCount - 1 do
      begin
        crrSize := Hex2Dec(Cells[SIZE_IMAGE_COLUMN, i]);
        crrAddr := Hex2Dec(Cells[ADDR_IMAGE_COLUMN, i]);
        if (addrToSearch >= crrAddr) and (addrToSearch <= crrSize +
          crrAddr) then
        begin
          Row := i;
          break;
        end;
      end; { with }
  end;

  sgFindText(StringGrid1, SearchBoxEdit.Text, []);
end;

procedure TMainForm.SearchBoxEditKeyPress(Sender: TObject; var Key: char);
begin

end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  StringGrid1EndDock(nil, nil, 0, 0);
  NamesArray := TDictionary<longint, string>.Create;
  dicT := TDictionary<integer, tDic>.Create;
  dicM := TDictionary<dword, mDic>.Create;
  sgsel := TStringList.Create;

  DragAcceptFiles(Handle, True);

  if paramcount > 0 then
  begin
    LoadDump(ParamStr(1));
    ProcessExportsBtnClick(nil);
    CheckDSOBtnClick(nil);
    MakeDICBtnClick(nil);
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FS.Free;
  NamesArray.Free;
  dicT.Free;
  dicM.Free;
  sgsel.Free;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  StringGrid1.ColWidths[1] := ClientWidth - 404;
end;

procedure TMainForm.SelectAlIMenuItemClick(Sender: TObject);
begin
  Memo.SelectAll;
end;

procedure TMainForm.StringGrid1DrawCell(Sender: TObject; ACol, ARow: integer;
  Rect: TRect; State: TGridDrawState);
var
  focus: TRect;
begin
  if StringGrid1.Cells[0, ARow] = ' v' then
  begin
    StringGrid1.Canvas.Brush.Color := clGreen;
    StringGrid1.Canvas.Font.Color := clWhite;
  end
  else
  begin
    StringGrid1.Canvas.Brush.Color := clWhite;
    StringGrid1.Canvas.Font.Color := clBlack;
  end;

  if (aRow = StringGrid1.Row) then
  begin
    StringGrid1.Canvas.Brush.Color := clYellow;
    StringGrid1.Canvas.Font.Color := clBlack;
  end;

  StringGrid1.Canvas.fillRect(Rect);
  StringGrid1.Canvas.TextOut(Rect.Left + 2, Rect.Top + 2,
    StringGrid1.Cells[ACol, ARow]);

end;

procedure TMainForm.StringGrid1EndDock(Sender, Target: TObject; X, Y: integer);
begin
  StringGrid1.RowCount := 2;
  StringGrid1.Rows[1].Clear;
  StringGrid1.ColWidths[0] := 20;
  StringGrid1.ColWidths[1] := ClientWidth - 404;
  StringGrid1.Cells[1, 0] := 'Name';
  StringGrid1.Cells[2, 0] := 'Size';
  StringGrid1.Cells[3, 0] := 'Address';
  StringGrid1.Cells[4, 0] := 'Exports';
end;

procedure TMainForm.StringGrid1KeyPress(Sender: TObject; var Key: char);
var
  b: string;
begin
  if Key = #$20 then
  begin
    if StringGrid1.Cells[0, StringGrid1.Row] = ' ' then
    begin
      StringGrid1.Cells[0, StringGrid1.Row] := ' v';
      sgsel.Add(IntToStr(StringGrid1.Row));
    end
    else
    begin
      StringGrid1.Cells[0, StringGrid1.Row] := ' ';
      sgsel.Delete(sgsel.IndexOf(IntToStr(StringGrid1.Row)));
    end;
    if sgsel.Count > 0 then
      RemoveSelectionBtn.Visible := True
    else
      RemoveSelectionBtn.Visible := False;
    StringGrid1.Repaint;
  end
  else
  if not (key in [#$25..#$28]) then
  begin
    //      showmessage(inttostr(ord(key)));
    if key = #8 then
    begin
      if Length(SearchBoxEdit.Text) > 0 then
      begin
        b := SearchBoxEdit.Text;
        SetLength(b, Length(b) - 1);
        SearchBoxEdit.Text := b;
      end;
    end
    else
    if key in ['-', '_', '(', ')', '.', '0'..'9', 'a'..'z', 'A'..'Z'] then
      SearchBoxEdit.Text := SearchBoxEdit.Text + Key;

  end;

end;

procedure TMainForm.StringGrid1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: integer);
var
  ARow, ACol: integer;
begin
  StringGrid1.MouseToCell(X, Y, ACol, ARow);
  if ACol = 0 then
  begin
    if StringGrid1.Cells[ACol, ARow] = ' ' then
    begin
      StringGrid1.Cells[ACol, ARow] := ' v';
      sgsel.Add(IntToStr(ARow));
    end
    else
    begin
      StringGrid1.Cells[ACol, ARow] := ' ';
      sgsel.Delete(sgsel.IndexOf(IntToStr(ARow)));
    end;
    if sgsel.Count > 0 then
      RemoveSelectionBtn.Visible := True
    else
      RemoveSelectionBtn.Visible := False;
    StringGrid1.Repaint;
  end;

end;

{$IFDEF WINDOWS}
procedure TMainForm.WMDropFiles(var Msg: TWMDropFiles);

  { ©Drkb v.3(2007): www.drkb.ru,
    ®Vit (Vitaly Nevzorov) - nevzorov@yahoo.com }

var
  CFileName: array [0 .. MAX_PATH] of char;
begin
  try
    if DragQueryFile(Msg.Drop, 0, CFileName, MAX_PATH) > 0 then
    begin
      Application.BringToFront;
      if Application.MessageBox('You really want to open new RomDump?',
        'Open new RomDump', MB_YESNO) = idYes then
      begin
        NamesArray.Clear;
        dicT.Clear;
        dicM.Clear;

        LoadDump(CFileName);
        ProcessExportsBtnClick(nil);
        CheckDSOBtnClick(nil);
        MakeDICBtnClick(nil);

        Msg.Result := 0;
      end;
    end;
  finally
    DragFinish(Msg.Drop);
  end;
end;
{$ENDIF}

end.
