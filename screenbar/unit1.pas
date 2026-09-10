unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Process,
  Clipbrd, ExtCtrls, DefaultTranslator, IniPropStorage;

type

  { TMainForm }

  TMainForm = class(TForm)
    Image1: TImage;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    SaveDialog1: TSaveDialog;
    ScanBtn: TButton;
    Memo1: TMemo;
    SaveBtn: TButton;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure SaveBtnClick(Sender: TObject);
    procedure ScanBtnClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private

  public

  end;

var
  MainForm: TMainForm;

resourcestring
  SCodeNotFound = 'Code not found...';
  SScreenshotFailed = 'Screenshot failed!';
  SZBarImgNotInstalled = 'zbarimg is not installed!';
  SScrotNotInstalled = 'scrot is not installed!';

implementation

{$R *.lfm}

{ TMainForm }

//Проверка существования утилиты / команды
function IsUtilityInstalled(const UtilityName: string): boolean;
var
  OutputString: string;
begin
  // Запускаем утилиту с флагом --version.
  // Если утилита существует, RunCommand вернет True.
  // Ошибки (StdErr) перенаправляем в StdOut, чтобы не плодить окна.
  Result := RunCommand(UtilityName, ['--version'], OutputString);
end;

//Декодирование кода из скриншота
function DecodeQRCode(const ScreenshotFile: string): string;
var
  AProcess: TProcess;
  OutputList: TStringList;
begin
  Result := '';

  AProcess := TProcess.Create(nil);
  OutputList := TStringList.Create;

  try
    AProcess.Executable := 'zbarimg';

    AProcess.Parameters.Add('-q');
    AProcess.Parameters.Add('--raw');
    AProcess.Parameters.Add('--nodbus');
    AProcess.Parameters.Add(ScreenshotFile);

    AProcess.Options := [poUsePipes, poWaitOnExit];

    AProcess.Execute;

    OutputList.LoadFromStream(AProcess.Output);

    if OutputList.Count > 0 then
      Result := Trim(OutputList.Text);

  finally
    OutputList.Free;
    AProcess.Free;
  end;
end;

//Скриншот пуст?
function FileIsNonEmpty(const FileName: string): boolean;
var
  SR: TSearchRec;
begin
  Result := False;

  if FindFirst(FileName, faAnyFile, SR) = 0 then
  begin
    try
      Result := SR.Size > 0;
    finally
      FindClose(SR);
    end;
  end;
end;

{
XDG_CURRENT_DESKTOP
        │
        ├── Budgie   (X11)  → scrot
        ├── GNOME           → gnome-screenshot
        ├── KDE             → spectacle
        ├── XFCE            → xfce4-screenshooter
        ├── LXQt     (X11)  → screengrab (не умеет молча сохранять в файл), scrot
        ├── LXDE     (X11)  → scrot
        ├── MATE     (X11)  → scrot
        └── Cinnamon (X11)  → scrot
}
// Получить скриншот
function TakeScreenshot(const ScreenshotFile: string): boolean;
var
  DE: string;
  S: string;
begin
  Result := False;

  // Старый файл нам не нужен:
  // иначе он может быть принят за результат нового запуска.
  if FileExists(ScreenshotFile) then
    DeleteFile(ScreenshotFile);

  DE := UpperCase(GetEnvironmentVariable('XDG_CURRENT_DESKTOP'));

  try
    if Pos('BUDGIE', DE) > 0 then
      Result := RunCommand('scrot', ['-o', ScreenshotFile], S)

    else if Pos('GNOME', DE) > 0 then
      Result := RunCommand('gnome-screenshot', ['-f', ScreenshotFile], S)

    else if Pos('KDE', DE) > 0 then
      Result := RunCommand('spectacle', ['--fullscreen', '--background',
        '--nonotify', '--output', ScreenshotFile], S)

    else if Pos('XFCE', DE) > 0 then
      Result := RunCommand('xfce4-screenshooter', ['-f', '-s', ScreenshotFile], S)

{   else if Pos('LXQT', DE) > 0 then
      Result := RunCommand('screengrab', ['-f', '-m', '-s', ScreenshotFile], S) }

    else if Pos('LXQT', DE) > 0 then
      Result := RunCommand('scrot', ['-o', ScreenshotFile], S)

    else if Pos('LXDE', DE) > 0 then
      Result := RunCommand('scrot', ['-o', ScreenshotFile], S)

    else if Pos('MATE', DE) > 0 then
      Result := RunCommand('scrot', ['-o', ScreenshotFile], S)

    else if Pos('CINNAMON', DE) > 0 then
      Result := RunCommand('scrot', ['-o', ScreenshotFile], S)

    else
      Exit;

  except
    on E: Exception do
    begin
      // При желании на этапе отладки:
      // Memo1.Text := E.Message;
      Exit;
    end;
  end;

  // Даже если RunCommand сообщил об успехе,
  // убеждаемся, что реально появился непустой файл.
  Result := Result and FileIsNonEmpty(ScreenshotFile);
end;

//Вывод текста из кода в Memo1 и копирование в буфер
procedure TMainForm.ScanBtnClick(Sender: TObject);
begin
  //zbarimg установлен?
  if not IsUtilityInstalled('zbarimg') then
  begin
    Memo1.Text := SZBarImgNotInstalled;
    Exit;
  end;

  //scrot установлен?
  if not IsUtilityInstalled('scrot') then
  begin
    Memo1.Text := SScrotNotInstalled;
    Exit;
  end;

  Memo1.Clear;
  ClipBoard.AsText := '';

  if TakeScreenshot(GetUserDir + '.config/screenbar/myscreen.png') then
  begin
    Memo1.Text := DecodeQRCode(GetUserDir + '.config/screenbar/myscreen.png');
    if Trim(Memo1.Text) = '' then Memo1.Text := SCodeNotFound
    else
    begin
      ClipBoard.AsText := Memo1.Text;
      Label1.Visible := True;
      Timer1.Interval := 3000;
      Timer1.Enabled := True;
    end;
  end
  else
    Memo1.Text := SScreenshotFailed;
end;

//Показ сообщения
procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  Label1.Visible := False;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  bmp: TBitmap;
begin
  MainForm.Caption := Application.Title;

  // Устраняем баг иконки приложения
  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf32bit;
    bmp.Assign(Image1.Picture.Graphic);
    Application.Icon.Assign(bmp);
  finally
    bmp.Free;
  end;

  if not DirectoryExists(GetUserDir + '.config/screenbar') then
    ForceDirectories(GetUserDir + '.config/screenbar');

  IniPropStorage1.IniFileName := GetUserDir + '.config/screenbar/screenbar.conf';

end;

//Сохранение в mycode.conf (например для NekoBox, Exclave и т.д.)
procedure TMainForm.SaveBtnClick(Sender: TObject);
begin
  if (Trim(Memo1.Text) <> '') and (Trim(Memo1.Text) <> SCodeNotFound) and
    (Trim(Memo1.Text) <> SScreenshotFailed) then
    if SaveDialog1.Execute then
      Memo1.Lines.SaveToFile(SaveDialog1.FileName);
end;

end.
