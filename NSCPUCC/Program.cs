using NSCPUCC;
using System.Globalization;

Console.WriteLine("NSCPUCC v0.01");

if (args.Length != 2)
    Console.WriteLine("  usage: NSCPUCC [input file] [output file]");
else
{
    bool hex = args[1].ToLower().EndsWith(".hex");

    Console.WriteLine("reading code...");
    string code = File.ReadAllText(args[0]);
    NSCPU.SetOutput((s) => Console.WriteLine(s));
    NSCPU cpu = NSCPU.GetExecutor(code);

    Console.WriteLine("compiling...");
    cpu.Run();
    
    byte[][] bytes = cpu.GetBytes();
    
    if (hex)
    {
        string str = ""; int addr = 0;
        for (int i = 0; i < bytes.Length; i++)
        {
            str += ":";
            string line = "";
            byte len = (byte)(bytes[i].Length & 0xFF);
            line += len.ToString("X2");
            line += (addr & 0xFFFF).ToString("X4");
            line += "00";
            for (int j = 0; j < len; j++)
                line += bytes[i][len - j - 1].ToString("X2");
            byte sum = 0;
            for (int k = 0; k < line.Length / 2; k++)
                sum += byte.Parse(line.Substring(k * 2, 2), NumberStyles.HexNumber);
            sum = (byte)(1 + ~sum);
            str += line;
            str += sum.ToString("X2");
            str += "\r\n";
            addr += len / 3;
        }
        str += ":00000001FF\r\n";
        Console.WriteLine("writing hex...");
        File.WriteAllText(args[1], str);
        Console.WriteLine("Wrote " + bytes.Length + " instrs.");
    }
    else
    {
        List<byte> buffer = new List<byte>();
        for (int i = 0; i < bytes.Length; i++)
            for (int j = 0; j < bytes[i].Length; j++)
                buffer.Add(bytes[i][j]);
        Console.WriteLine("writing binary...");
        File.WriteAllBytes(args[1], buffer.ToArray());
        Console.WriteLine("Wrote " + buffer.Count + " bytes.");
    }
}

Console.WriteLine();
