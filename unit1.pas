unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Process,
  FileUtil, StrUtils, Math; // Добавлен Math

type
  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ComboBox1: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure FindJarFiles;
    function GetJavaVersion: string;
    function GetAppVersion(const JarPath: string): string;
    procedure LogError(const Msg: string; Critical: Boolean = False);
    procedure InitializeForm;
  public
  end;

function CompareVersionProc(List: TStringList; Index1, Index2: Integer): Integer; // Объявление вне класса

const
  LauncherVersion = '1.0.2';
  JavaInstaller = 'OpenJDK21U-jdk_x64_windows_hotspot_21.0.8_9.msi';
  LogDir = 'ElephantMonitor';

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

function CompareVersionProc(List: TStringList; Index1, Index2: Integer): Integer;
var
  Version1, Version2: string;
  V1Parts, V2Parts: TStringList;
  V1Num, V2Num, I: Integer;
  V1Status, V2Status: string;
  V1Base, V2Base: string;
begin
  // Извлекаем версии из списка
  Version1 := Copy(List[Index1], 1, Pos(';', List[Index1]) - 1);
  Version2 := Copy(List[Index2], 1, Pos(';', List[Index2]) - 1);

  // Извлекаем числовую часть и статус
  V1Base := Version1;
  V2Base := Version2;
  V1Status := '';
  V2Status := '';

  if Pos('-', Version1) > 0 then
  begin
    V1Base := Copy(Version1, 1, Pos('-', Version1) - 1);
    V1Status := Copy(Version1, Pos('-', Version1) + 1, Length(Version1));
  end;
  if Pos('-', Version2) > 0 then
  begin
    V2Base := Copy(Version2, 1, Pos('-', Version2) - 1);
    V2Status := Copy(Version2, Pos('-', Version2) + 1, Length(Version2));
  end;

  // Разбиваем числовую часть на компоненты
  V1Parts := TStringList.Create;
  V2Parts := TStringList.Create;
  try
    V1Parts.Delimiter := '.';
    V2Parts.Delimiter := '.';
    V1Parts.DelimitedText := V1Base;
    V2Parts.DelimitedText := V2Base;

    // Сравниваем числовые компоненты
    for I := 0 to Min(V1Parts.Count, V2Parts.Count) - 1 do
    begin
      V1Num := StrToIntDef(V1Parts[I], 0);
      V2Num := StrToIntDef(V2Parts[I], 0);
      if V1Num > V2Num then
        Exit(-1) // Version1 больше, ставим раньше
      else if V1Num < V2Num then
        Exit(1); // Version2 больше, ставим раньше
    end;

    // Если числовые части равны, сравниваем длину
    if V1Parts.Count <> V2Parts.Count then
      Exit(V2Parts.Count - V1Parts.Count); // Более длинная версия новее

    // Если числовые части равны, сравниваем статус (Alpha > Beta > '')
    if (V1Status = V2Status) then
      Exit(0)
    else if (V1Status = 'Alpha') and (V2Status = 'Beta') then
      Exit(-1) // Alpha новее Beta
    else if (V1Status = 'Beta') and (V2Status = 'Alpha') then
      Exit(1)
    else if (V1Status = '') then
      Exit(1) // Версия без статуса старее
    else if (V2Status = '') then
      Exit(-1); // Версия без статуса старее
  finally
    V1Parts.Free;
    V2Parts.Free;
  end;
end;

procedure TForm1.LogError(const Msg: string; Critical: Boolean = False);
var
  LogMessage: string;
  LogPath: string;
begin
  LogMessage := 'Launcher v' + LauncherVersion + ': ' + Msg;
  Label4.Caption := 'Лог: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + LogMessage;
  if Critical then
    ShowMessage('Ошибка: ' + Msg);
  // Логирование в пользовательскую папку
  try
    LogPath := GetEnvironmentVariable('APPDATA') + PathDelim + LogDir + PathDelim + 'launcher_errors.log';
    ForceDirectories(GetEnvironmentVariable('APPDATA') + PathDelim + LogDir);
    with TFileStream.Create(LogPath, fmCreate or fmAppend) do
    try
      Write(PChar(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + LogMessage + sLineBreak)^,
            Length(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + LogMessage + sLineBreak));
    finally
      Free;
    end;
  except
    on E: Exception do
      Label4.Caption := 'Лог: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' Ошибка записи в лог: ' + E.Message;
  end;
end;

procedure TForm1.InitializeForm;
var
  JavaVer: string;
  InstallerPath: string;
begin
  try
    LogError('Начало InitializeForm');

    // Настраиваем элементы интерфейса
    Caption := 'Elephant Monitor Launcher v' + LauncherVersion;
    Width := 500;
    Height := 350;
    Position := poScreenCenter;

    Label1.Caption := 'Выберите версию приложения:';
    Label1.Top := 20;
    Label1.Left := 20;

    ComboBox1.Top := 50;
    ComboBox1.Left := 20;
    ComboBox1.Width := 450;
    ComboBox1.Style := csDropDownList;

    Button1.Caption := 'Запустить';
    Button1.Top := 100;
    Button1.Left := 20;
    Button1.Width := 100;

    Button2.Caption := 'Обновить';
    Button2.Top := 100;
    Button2.Left := 130;
    Button2.Width := 100;

    Button3.Caption := 'Запустить установку Java';
    Button3.Top := 100;
    Button3.Left := 240;
    Button3.Width := 250;
    Button3.Enabled := False;

    Label2.Top := 150;
    Label2.Left := 20;
    Label2.Caption := 'Инициализация Java...';

    Label3.Top := 180;
    Label3.Left := 20;
    Label3.Caption := 'Версия: Не выбрано';

    Label4.Top := 210;
    Label4.Left := 20;
    Label4.Caption := '';

    Label5.Top := 240;
    Label5.Left := 20;
    Label5.Caption := 'Инициализация начата';

    // Проверка версии Java
    LogError('Запуск проверки Java...');
    try
      JavaVer := GetJavaVersion;
      if JavaVer <> '' then
      begin
        Label2.Caption := 'Установлена Java: ' + JavaVer;
        Button1.Enabled := True;
      end
      else
      begin
        Label2.Caption := 'Java не обнаружена!';
        InstallerPath := ExtractFilePath(Application.ExeName) + JavaInstaller;
        if FileExists(InstallerPath) then
        begin
          Button3.Enabled := True;
          LogError('Найден установщик Java: ' + InstallerPath);
        end
        else
        begin
          LogError('Установщик Java не найден: ' + InstallerPath, True);
          Button1.Enabled := False;
        end;
      end;
    except
      on E: Exception do
      begin
        LogError('Ошибка при получении версии Java: ' + E.Message, True);
        Label2.Caption := 'Ошибка Java';
        InstallerPath := ExtractFilePath(Application.ExeName) + JavaInstaller;
        if FileExists(InstallerPath) then
        begin
          Button3.Enabled := True;
          LogError('Найден установщик Java: ' + InstallerPath);
        end
        else
        begin
          LogError('Установщик Java не найден: ' + InstallerPath, True);
          Button1.Enabled := False;
        end;
      end;
    end;

    // Поиск JAR-файлов
    LogError('Запуск поиска JAR-файлов...');
    try
      LogError('Путь к приложению: ' + ExtractFilePath(Application.ExeName));
      FindJarFiles;
    except
      on E: Exception do
      begin
        LogError('Ошибка при поиске JAR: ' + E.Message, True);
        ComboBox1.Items.Add('Ошибка поиска файлов');
        ComboBox1.ItemIndex := 0;
        Button1.Enabled := False;
        Label3.Caption := '';
      end;
    end;

    Label5.Caption := 'Инициализация завершена';
  except
    on E: Exception do
    begin
      LogError('Ошибка при инициализации формы: ' + E.Message, True);
      Label2.Caption := 'Ошибка инициализации';
      Button1.Enabled := False;
      Label5.Caption := 'Инициализация прервана';
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  // Проверка аргументов командной строки
  for I := 1 to ParamCount do
  begin
    if LowerCase(ParamStr(I)) = '--version' then
    begin
      WriteLn('Elephant Monitor Launcher v' + LauncherVersion);
      Application.Terminate;
      Exit;
    end;
  end;
  LogError('FormCreate вызван');
  InitializeForm;
end;

procedure TForm1.FindJarFiles;
var
  Files: TStringList;
  I: Integer;
  AppPath, JarPath: string;
  VersionList: TStringList;
  Version, FileName: string;
begin
  try
    AppPath := ExtractFilePath(Application.ExeName);
    if not DirectoryExists(AppPath) then
    begin
      LogError('Директория приложения не найдена: ' + AppPath, True);
      ComboBox1.Items.Add('Директория недоступна');
      ComboBox1.ItemIndex := 0;
      Button1.Enabled := False;
      Label3.Caption := '';
      Exit;
    end;

    Files := TStringList.Create;
    VersionList := TStringList.Create;
    try
      Files := FindAllFiles(AppPath, 'Elephant*.jar', False);
      LogError('Найдено JAR-файлов: ' + IntToStr(Files.Count));

      // Создаём список пар "версия;имя файла"
      for I := 0 to Files.Count - 1 do
      begin
        JarPath := Files[I];
        if FileExists(JarPath) then
        begin
          FileName := ExtractFileName(JarPath);
          // Извлекаем версию из имени файла (например, "1.8.18-Beta" из "Elephant-Monitor-1.8.18-Beta.jar")
          Version := Copy(FileName, Pos('-', FileName) + 1, Length(FileName));
          Version := Copy(Version, 1, Pos('.jar', Version) - 1);
          VersionList.Add(Version + ';' + FileName);
        end;
      end;

      // Сортируем версии от новой к старой
      VersionList.CustomSort(@CompareVersionProc);

      ComboBox1.Items.BeginUpdate;
      try
        ComboBox1.Items.Clear;

        if VersionList.Count > 0 then
        begin
          for I := 0 to VersionList.Count - 1 do
          begin
            FileName := Copy(VersionList[I], Pos(';', VersionList[I]) + 1, Length(VersionList[I]));
            ComboBox1.Items.Add(FileName);
          end;

          ComboBox1.ItemIndex := 0;
          Button1.Enabled := True;
          Label3.Caption := 'Версия: ' + GetAppVersion(ExtractFilePath(Application.ExeName) + ComboBox1.Items[0]);
        end
        else
        begin
          ComboBox1.Items.Add('JAR-файлы не найдены!');
          ComboBox1.ItemIndex := 0;
          Button1.Enabled := False;
          Label3.Caption := '';
        end;
      finally
        ComboBox1.Items.EndUpdate;
      end;
    finally
      Files.Free;
      VersionList.Free;
    end;
  except
    on E: Exception do
    begin
      LogError('Ошибка при поиске JAR-файлов: ' + E.Message, True);
      ComboBox1.Items.Clear;
      ComboBox1.Items.Add('Ошибка поиска файлов');
      ComboBox1.ItemIndex := 0;
      Button1.Enabled := False;
      Label3.Caption := '';
    end;
  end;
end;

function TForm1.GetJavaVersion: string;
var
  Process: TProcess;
  Output: TStringList;
  OutputStr: string;
begin
  Result := '';
  Process := TProcess.Create(nil);
  Output := TStringList.Create;
  try
    LogError('Инициализация процесса для java -version...');
    Process.Executable := 'java';
    Process.Parameters.Add('-version');
    Process.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    Process.ShowWindow := swoHIDE;

    try
      LogError('Запуск команды java -version...');
      Process.Execute;
      LogError('Ожидание завершения java -version...');
      Process.WaitOnExit;
      Output.LoadFromStream(Process.Output);
      LogError('Вывод java -version: ' + Output.Text);
      if Output.Count > 0 then
      begin
        OutputStr := Output[0];
        if Pos('version', OutputStr) > 0 then
        begin
          Result := Copy(OutputStr, Pos('"', OutputStr) + 1, 10);
          Result := Copy(Result, 1, Pos('"', Result) - 1);
          LogError('Версия Java: ' + Result);
        end
        else
          LogError('Версия Java не найдена в выводе');
      end
      else
        LogError('Вывод команды java -version пустой');
    except
      on E: Exception do
      begin
        LogError('Ошибка при получении версии Java: ' + E.Message, True);
        Result := '';
      end;
    end;
  finally
    Output.Free;
    Process.Free;
  end;
end;

function TForm1.GetAppVersion(const JarPath: string): string;
var
  F: File;
  Buffer: array[0..1023] of Byte;
  Content: string;
  StartPos, EndPos: Integer;
begin
  Result := 'Неизвестно';

  if not FileExists(JarPath) then
  begin
    LogError('JAR-файл не найден: ' + JarPath);
    Exit;
  end;

  try
    AssignFile(F, JarPath);
    FileMode := fmOpenRead;
    try
      Reset(F, 1);
      try
        BlockRead(F, Buffer, SizeOf(Buffer));
        Content := TEncoding.ASCII.GetString(Buffer);

        StartPos := Pos('Implementation-Version:', Content);
        if StartPos > 0 then
        begin
          StartPos := StartPos + Length('Implementation-Version:');
          EndPos := PosEx(#10, Content, StartPos);
          if EndPos > StartPos then
          begin
            Result := Copy(Content, StartPos, EndPos - StartPos).Trim;
            LogError('Версия JAR: ' + Result);
          end;
        end;
      finally
        CloseFile(F);
      end;
    except
      on E: Exception do
      begin
        LogError('Ошибка при чтении JAR-файла: ' + E.Message);
        Result := 'Ошибка чтения';
      end;
    end;
  except
    on E: Exception do
    begin
      LogError('Ошибка при открытии JAR-файла: ' + E.Message);
      Result := 'Ошибка открытия';
    end;
  end;
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
var
  JarPath: string;
begin
  try
    if ComboBox1.ItemIndex >= 0 then
    begin
      JarPath := ExtractFilePath(Application.ExeName) + ComboBox1.Items[ComboBox1.ItemIndex];
      if FileExists(JarPath) then
        Label3.Caption := 'Версия: ' + GetAppVersion(JarPath)
      else
        Label3.Caption := 'Версия: Файл не найден';
    end
    else
      Label3.Caption := 'Версия: Не выбрано';
  except
    on E: Exception do
    begin
      LogError('Ошибка при смене JAR-файла: ' + E.Message, True);
      Label3.Caption := 'Версия: Ошибка';
    end;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  JarPath: String;
  Process: TProcess;
  JavaExe: string;
begin
  try
    LogError('Button1Click: Начало запуска JAR...');
    if ComboBox1.ItemIndex < 0 then
    begin
      LogError('Выберите версию приложения для запуска!', True);
      Exit;
    end;

    JarPath := ExtractFilePath(Application.ExeName) + ComboBox1.Items[ComboBox1.ItemIndex];
    LogError('Проверка JAR-файла: ' + JarPath);

    if not FileExists(JarPath) then
    begin
      LogError('Файл не найден: ' + JarPath, True);
      Exit;
    end;

    // Используем javaw из PATH
    JavaExe := 'javaw';
    LogError('Попытка использовать javaw из PATH: ' + JavaExe);

    // Проверяем альтернативные пути, если PATH не сработает
    try
      Process := TProcess.Create(nil);
      try
        Process.Executable := JavaExe;
        Process.Parameters.Add('-jar');
        Process.Parameters.Add('"' + JarPath + '"');
        Process.Options := [poNoConsole];
        Process.ShowWindow := swoHIDE;
        LogError('Запуск команды: ' + JavaExe + ' -jar "' + JarPath + '"');
        Process.Execute;
        LogError('JAR запущен, завершение лаунчера');
        Application.Terminate;
      finally
        Process.Free;
      end;
    except
      on E: Exception do
      begin
        LogError('Ошибка при запуске с javaw из PATH: ' + E.Message);
        // Пробуем стандартные пути
        JavaExe := 'C:\Program Files\Java\jre\bin\javaw.exe';
        if FileExists(JavaExe) then
        begin
          LogError('Попытка использовать javaw: ' + JavaExe);
          Process := TProcess.Create(nil);
          try
            Process.Executable := JavaExe;
            Process.Parameters.Add('-jar');
            Process.Parameters.Add('"' + JarPath + '"');
            Process.Options := [poNoConsole];
            Process.ShowWindow := swoHIDE;
            LogError('Запуск команды: ' + JavaExe + ' -jar "' + JarPath + '"');
            Process.Execute;
            LogError('JAR запущен, завершение лаунчера');
            Application.Terminate;
          finally
            Process.Free;
          end;
        end
        else
        begin
          JavaExe := 'C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot\bin\javaw.exe';
          if FileExists(JavaExe) then
          begin
            LogError('Попытка использовать javaw: ' + JavaExe);
            Process := TProcess.Create(nil);
            try
              Process.Executable := JavaExe;
              Process.Parameters.Add('-jar');
              Process.Parameters.Add('"' + JarPath + '"');
              Process.Options := [poNoConsole];
              Process.ShowWindow := swoHIDE;
              LogError('Запуск команды: ' + JavaExe + ' -jar "' + JarPath + '"');
              Process.Execute;
              LogError('JAR запущен, завершение лаунчера');
              Application.Terminate;
            finally
              Process.Free;
            end;
          end
          else
          begin
            LogError('javaw.exe не найден в системе!', True);
            Exit;
          end;
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      LogError('Ошибка при запуске приложения: ' + E.Message, True);
    end;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  LogError('Button2Click: Принудительная инициализация');
  InitializeForm;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  InstallerPath: string;
  Process: TProcess;
begin
  try
    LogError('Button3Click: Запуск установщика Java...');
    InstallerPath := ExtractFilePath(Application.ExeName) + JavaInstaller;
    if not FileExists(InstallerPath) then
    begin
      LogError('Установщик Java не найден: ' + InstallerPath, True);
      Exit;
    end;

    Process := TProcess.Create(nil);
    try
      Process.Executable := 'msiexec';
      Process.Parameters.Add('/i');
      Process.Parameters.Add('"' + InstallerPath + '"');
      Process.Options := [];
      Process.ShowWindow := swoShow;
      LogError('Запуск команды: msiexec /i "' + InstallerPath + '"');
      Process.Execute;
      Process.WaitOnExit;
      LogError('Установщик Java завершил работу');
      // Перезапуск launcher.exe
      try
        Process := TProcess.Create(nil);
        try
          Process.Executable := Application.ExeName;
          Process.Options := [poNoConsole];
          Process.ShowWindow := swoShow;
          LogError('Перезапуск лаунчера: ' + Application.ExeName);
          Process.Execute;
          LogError('Лаунчер перезапущен, завершение текущего процесса');
          Application.Terminate;
        finally
          Process.Free;
        end;
      except
        on E: Exception do
        begin
          LogError('Ошибка при перезапуске лаунчера: ' + E.Message, True);
        end;
      end;
    finally
      Process.Free;
    end;
  except
    on E: Exception do
    begin
      LogError('Ошибка при запуске установщика Java: ' + E.Message, True);
    end;
  end;
end;

end.
