program BarnsleyFullHD;

{$mode objfpc}{$H+}

uses
   Classes;   { for TThread }
type
    TXY = object
                X, Y: double;
                procedure transform();
    end;
    TByteArray = array[0..$7FFFFFFE] of Byte;

    TRendererThread = class(TThread)
    private
            MyPoint: TXY;
            Iterations: Int64;
            procedure ShowCurrentState;
    protected
            procedure Execute(); override;
    public
            constructor Create(XY: TXY; Iters: Int64);
    end;
var
   Image: ^TByteArray;
   Height, Width: Dword;
procedure TXY.transform();
var nX, nY: double;
begin
     case random(100) of
     0..1: begin nX := 0; nY := 0.16*Y; end;
     2..6: begin nX := 0.2*X - 0.26*Y; nY := 0.23*X + 0.22*Y + 1.6; end;
     7..13: begin nX := -0.15*X + 0.28*Y; nY := 0.26*X + 0.24*Y + 0.44; end;
     14..99: begin nX := 0.85*X + 0.04*Y; nY := -0.04*X + 0.85*Y + 1.6; end;
     end; X := nX; Y := nY;
end;

constructor TRendererThread.Create(XY: TXY; Iters: Int64);
begin
     FreeOnTerminate := True;
     MyPoint := XY;
     Iterations := Iters;
     inherited Create(False);
end;
procedure TRendererThread.ShowCurrentState;
begin
     Writeln('pX=',MyPoint.x,' pY=',MyPoint.y);
     readln;
end;

procedure TRendererThread.Execute();
const
     boundLeftX = -2.2;//-2.1818;
     boundRightX = 2.7;//2.6556;
     boundY = 10;//9.95851;
     a_boundLeftX = abs(boundLeftX);
     s_efficientX = a_boundLeftX + boundRightX;
var
   Iters: Int64;
   iX, iY: Dword;
begin
     Iters := Iterations;
     while (Iters > 0) do
     begin
          iX := round(  MyPoint.X * ((Width-2)/s_efficientX) + (a_boundLeftX)*(Width-2)/(s_efficientX));
          iY := round(  MyPoint.Y * ((Height-2)/boundY)  );

 {         if iX > Width-1 then begin ShowCurrentState; Halt; end;
          if iY > Height-1 then begin ShowCurrentState; Halt; end;
          if iX < 0 then begin ShowCurrentState; Halt; end;
          if iY < 0 then begin ShowCurrentState; Halt; end;}

          Image^[iX+iY*Width] := 1;
          Iters -= 1;
          MyPoint.transform();
     end;
     Writeln('Watek konczy!');
end;

type
    TBitmapHeader = record
      Size: Dword;
      AppSpec: Dword;  {0}
      Offset: Dword;   {54}
      NrHeader: Dword; {40}
      Width: Dword;
      Height: Dword;
      CPlanes: Word;      {1}
      BPP: Word;          {24}
      Compression: Dword;{0}
      RawBMPData: Dword;
      DPIWidth: Dword;
      DPIHeight: Dword;
      ColorsInPalette: Dword; {0}
      ImpColors: Dword;       {0}
    end;

var
   Iterations: Int64;
   Cores: Byte;
   _iCores: Byte;
   Renderers: array[0..32] of TRendererThread;
   p: TXY;
   _iW, _iH: Dword;
   Bitmap: File;
   BitmapPath: String;
   BH: TBitmapHeader;
   padding: byte;
begin
     Write('Podaj rozmiar bitmapy [szerokosc] [wysokosc]: ');
     Readln(Width, Height);
     GetMem(Image, Width*Height);
     for _iW := 0 to Width-1 do for _iH := 0 to Height-1 do Image^[_iW+_iH*Width] := 0;
     Write('Podaj ilosc iteracji: ');
     Readln(Iterations);
     Write('Podaj ilosc rdzeni: ');
     Readln(Cores);
     p.x := 0; p.y := 0;
     for _iCores := 0 to Cores-1 do
     begin
          Renderers[_iCores] := TRendererThread.Create(p, Iterations);
          p.transform()
     end;
     Writeln('Nacisnij ENTER jak wszystkie ',Cores,' watkow skonczy. Kazdy wyswietli komunikat po zakonczeniu!');
     Writeln('Jesli masz 4 rdzenie, to po zobaczeniu 4 komunikatow "watek konczy" nacisnij ENTER');
     Readln;
     Write('Podaj sciezke do pliku wynikowego: ');
     Readln(BitmapPath);


     AssignFile(Bitmap, BitmapPath);
     Rewrite(Bitmap, 1);

     BH.AppSpec := 0; BH.NrHeader := 40; BH.CPlanes := 1; BH.BPP := 8;
     BH.Compression := 0; BH.ColorsInPalette := 2; BH.ImpColors := 0; BH.Offset := $36 + 8;
     BH.Width := Width; BH.Height := Height;
     padding := 4-(Width mod 4);
     if padding = 4 then padding := 0;
     BH.DPIWidth := 2835;
     BH.DPIHeight := 2835;

     BH.RawBMPData := Height * (Width + padding);
     BH.Size := $36 + 8 + BH.RawBMPData;

     BlockWrite(Bitmap, 'BM', 2);
     BlockWrite(Bitmap, BH, SizeOf(TBitmapHeader));

     Writeln('Raw Size: ',BH.RawBMPData);
     Writeln('Row Size: ',(Width + padding));
     Writeln('Total BMP Size: ',BH.Size);

     BlockWrite(Bitmap, 0, 4);
     BlockWrite(Bitmap, $FFFFFFFF, 4);

     for _iH := Height-1 downto 0 do
     begin
         Blockwrite(Bitmap, image^[_iH*Width], Width);
         Blockwrite(Bitmap,0,padding);
     end;
     closefile(Bitmap);
     readln;
end.

