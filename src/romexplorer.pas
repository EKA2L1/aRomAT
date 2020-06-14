unit RomExplorer;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TRomEntry = record
    iAttrib: byte;
    iName: UnicodeString;
    iEntryInfoAddrLin: dword;
    iDataAddr: dword;
    iFileSize: dword;
  end;

  TRomExplorer = class(TObject)
  private
    iRomStream: TStream;
    iRomBase: dword;
    iRomRootAddrLin: dword;
    iDirSize: dword;
    iDirStart: dword;

  public
    constructor Create(var romStream: TStream);
    function GetRomEntry(path: UnicodeString; var entry: TRomEntry): boolean;
    function RomToOffset(addr: dword): dword;
    function RomToOffsetBase(addr: dword): dword;

    function OffsetToRom(off: dword): dword;

    function BeginDirIterate(var entry: TRomEntry): boolean;
    function EndDirIterate: boolean;
    function GetNextEntry(var entry: TRomEntry; var encoding: TEncoding): boolean;
  end;

implementation

constructor TRomExplorer.Create(var romStream: TStream);
begin
   iRomStream := romStream;
   iRomStream.Seek($8C, soBeginning);
   iRomStream.Read(iRomBase, 4);
   iRomStream.Seek(4, soCurrent);
   iRomStream.Read(iRomRootAddrLin, 4);

   // Skip hardware variant and root count
   iRomStream.Seek(RomToOffset(iRomRootAddrLin) + 8, soBeginning);
   iRomStream.Read(iRomRootAddrLin, 4);

   iDirStart := 0;
   iDirSize := 0;
end;

function TRomExplorer.OffsetToRom(off: dword): dword;
begin
  Result := iRomBase + off;
end;

function TRomExplorer.RomToOffset(addr: dword): dword;
begin
  Result := addr - iRomBase;
end;

function TRomExplorer.RomToOffsetBase(addr: dword): dword;
begin
  Result := (addr shr 28) * $10000000;
end;

function TRomExplorer.GetNextEntry(var entry: TRomEntry; var encoding: TEncoding): boolean;
var nameLen: dword;
    nameRaw: TBytes;
begin
  nameLen := 0;
  nameRaw := TBytes.Create;

  if iRomStream.Position - iDirStart < iDirSize then
  begin
    entry.iEntryInfoAddrLin := iRomStream.Position + iRomBase;

    iRomStream.Read(entry.iFileSize, 4);
    iRomStream.Read(entry.iDataAddr, 4);
    iRomStream.REad(entry.iAttrib, 1);
    iRomStream.Read(nameLen, 1);
    SetLength(nameRaw, nameLen * 2);
    iRomStream.Read(nameRaw[0], nameLen * 2);

    entry.iName := Encoding.GetString(nameRaw);

    if (iRomStream.Position mod 4 <> 0) then
       iRomStream.Position := iRomStream.Position + 2;

    Result := True;
  end
  else
    Result := False;
end;

function TRomExplorer.BeginDirIterate(var entry: TRomEntry): boolean;
begin
  if ((entry.iAttrib and $10) = 0) or (iDirStart <> 0) then
     exit(False);

  iDirStart := RomToOffset(entry.iDataAddr);
  iDirSize := entry.iFileSize;

  iRomStream.Position := iDirStart;
  iRomStream.Read(iDirSize, 4);

  Result := True;
end;

function TRomExplorer.EndDirIterate: boolean;
begin
  if iDirStart = 0 then
     exit(false);

  iDirStart := 0;
  exit(True);
end;

function TRomExplorer.GetRomEntry(path: UnicodeString; var entry: TRomEntry): boolean;
var delimiterPos: dword;
    folderName, pathDir, pathName: UnicodeString;
    Encoding: TEncoding;
    shouldCancel: boolean;
begin
   pathDir := UnicodeString(ExtractFileDir(path)) + '\';
   delimiterPos := Pos('\', pathDir);

   entry.iDataAddr := iRomRootAddrLin;
   entry.iAttrib := $10;

   Encoding := TEncoding.Unicode;

   while delimiterPos <> 0 do
   begin
     folderName := copy(pathDir, 1, delimiterPos - 1);
     delete(pathDir, 1, delimiterPos);

     shouldCancel := true;

     if Length(folderName) = 0 then
       break;

     if not BeginDirIterate(entry) then
        exit(false);

     while GetNextEntry(entry, Encoding) do
     begin
        if (lowercase(entry.iName) = lowercase(folderName)) and
           (entry.iAttrib and $10 <> 0) then
        begin
          delimiterPos := Pos('\', pathDir);
          shouldCancel := false;
          break;
        end;
     end;

     EndDirIterate;

     if (shouldCancel) then
       exit(false);
   end;

   // Get the filename
   pathName := ExtractFileName(path);

   if Length(pathName) = 0 then
     exit(true);

   if not BeginDirIterate(entry) then
     exit(false);

   while GetNextEntry(entry, encoding) do
   begin
      if (lowercase(entry.iName) = lowercase(pathName)) then
      begin
        exit(true);
      end;
   end;

   Result := False;
end;

end.

