unit FileUtils;

{$mode delphi}

interface

uses
  Classes, SysUtils;
    
function ReadLineAscii(Stream: TStream; var Line: AnsiString): boolean;

implementation

// Read an ASCII line from a TStream.
function ReadLineAscii(Stream: TStream; var Line: AnsiString): boolean;
var
  ch: AnsiChar;
  StartPos, LineLen: integer;
begin
  result := False;
  StartPos := Stream.Position;
  ch := #0;
  while (Stream.Read( ch, 1) = 1) and (ch <> #13) do;
  LineLen := Stream.Position - StartPos;
  Stream.Position := StartPos;
  SetString(Line, NIL, LineLen);
  Stream.ReadBuffer(Line[1], LineLen);
  if ch = #13 then
    begin
    result := True;
    if (Stream.Read( ch, 1) = 1) and (ch <> #10) then
      Stream.Seek(-1, soCurrent) // unread it if not LF character.
    end
end;

end.

