using System;
using System.Globalization;
using System.Collections.Generic;

using dotNSASM;

namespace NSCPUCC
{
    public class NSCPU : NSASM
    {
        public static void SetOutput(Util.Printer printer)
        {
            Util.Output = printer;
        }

        readonly List<byte[]> byteCode;
        readonly Dictionary<string, int> jumpMap;
        protected int jumpPtr = 0;

        NSCPU(string[][] code) : base(16, 16, 8, code)
        {
            byteCode = new List<byte[]>();
            jumpMap = new Dictionary<string, int>();
        }

        public static NSCPU GetExecutor(string code)
        {
            // 防止仅使用了无操作数指令时, Run() 返回 null (即 prevDstReg 为 null)
            code += "\n___ \"END OF CODE\"\n";
            var c = Util.GetSegments(code);
            return new NSCPU(c);
        }

        protected override NSASM Instance(NSASM super, string[][] code)
        {
            return new NSCPU(code);
        }

        public byte[][] GetBytes()
        {
            return byteCode.ToArray();
        }

        public new Register Run()
        {
            byteCode.Clear();
            jumpMap.Clear();
            jumpPtr = 0;
            return base.Run();
        }

        protected bool VerifyTag(string var)
        {
            if (var.Length == 0) return false;
            return var[0] == '[' && var[^1] == ']';
        }

        protected bool ParseTag(string var, out int res)
        {
            res = 0;

            int tmp;
            if (
                (var.Contains("x") || var.Contains("X")) ^
                (var.Contains("h") || var.Contains("H"))
            )
            {
                if (
                    (var.Contains("x") || var.Contains("X")) &&
                    (var.Contains("h") || var.Contains("H"))
                ) return false;
                if (
                    (var[0] < '0' || var[0] > '9') &&
                    (var[0] != '+' || var[0] != '-')
                ) return false;
                try
                {
                    tmp = int.Parse(
                            var.Replace("h", "").Replace("H", "")
                               .Replace("x", "").Replace("X", ""),
                        NumberStyles.HexNumber);
                }
                catch (Exception)
                {
                    return false;
                }
            }
            else
            {
                try
                {
                    tmp = int.Parse(var);
                }
                catch (Exception)
                {
                    return false;
                }
            }

            res = tmp;
            return true;
        }

        protected void AddCode(params int[] bytes)
        {
            byte[] buf = new byte[bytes.Length];
            for (int i = 0; i < bytes.Length; i++)
                buf[i] = (byte)bytes[i];
            byteCode.Add(buf);
            jumpPtr += bytes.Length / 3;
        }

        protected void AddCode(int i)
        {
            AddCode(i & 0xFF, (i >> 8) & 0xFF, (i >> 16) & 0xFF);
        }

        protected override void LoadFuncList()
        {
            base.LoadFuncList();

            funcList.Add("___", (dst, src, ext) =>
            {
                return Result.OK;
            });

            funcList.Add(".tag", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;
                
                jumpMap.Add((string)dst.data, jumpPtr);

                return Result.OK;
            });

            funcList.Add(".nop", (dst, src, ext) =>
            {
                if (dst != null) return Result.ERR;
                if (src != null) return Result.ERR;

                AddCode(0x00, 0x00, 0x00);
                return Result.OK;
            });

            funcList.Add(".mov", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                        return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0x3F, 0x07, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0x3F, 0x03, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }
                
                return Result.ERR;
            });

            funcList.Add(".add", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0x5F, 0x07, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0x5F, 0x03, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".sub", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0x7F, 0x07, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0x7F, 0x03, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".int", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                        return Result.ERR;

                    AddCode(0x87, 0x03, 0x00);
                    AddCode(daddr);

                    return Result.OK;
                }
                else if (dst.type == RegType.CHAR || dst.type == RegType.INT)
                {
                    AddCode(0x87, 0x01, 0x00);
                    AddCode((int)dst.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".jmp", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                        return Result.ERR;

                    AddCode(0xA7, 0x03, 0x00);
                    AddCode(daddr);

                    return Result.OK;
                }
                else if (dst.type == RegType.CHAR || dst.type == RegType.INT)
                {
                    AddCode(0xA7, 0x01, 0x00);
                    AddCode((int)dst.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".jnz", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!jumpMap.ContainsKey((string)dst.data))
                        return Result.ERR;
                    AddCode(0xC7, 0x01, 0x00);
                    AddCode(jumpMap[(string)dst.data]);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".hlt", (dst, src, ext) =>
            {
                if (dst != null) return Result.ERR;
                if (src != null) return Result.ERR;

                AddCode(0xE0, 0x00, 0x00);

                return Result.OK;
            });

            funcList.Add(".push", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                        return Result.ERR;

                    AddCode(0x07, 0x0B, 0x00);
                    AddCode(daddr);

                    return Result.OK;
                }
                else if (dst.type == RegType.CHAR || dst.type == RegType.INT)
                {
                    AddCode(0x07, 0x09, 0x00);
                    AddCode((int)dst.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".pop", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                AddCode(0x27, 0x0B, 0x00);
                AddCode(daddr);

                return Result.OK;
            });

            funcList.Add(".not", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                AddCode(0x47, 0x0B, 0x00);
                AddCode(daddr);

                return Result.OK;
            });

            funcList.Add(".and", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0x7F, 0x0F, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0x7F, 0x0B, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".or", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0x9F, 0x0F, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0x9F, 0x0B, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".xor", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0xBF, 0x0F, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0xBF, 0x0B, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".shl", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0xDF, 0x0F, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0xDF, 0x0B, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".shr", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                if (src.type == RegType.STR && VerifyTag((string)src.data))
                {
                    if (!ParseTag(((string)src.data)[1..^1], out int saddr))
                        return Result.ERR;

                    AddCode(0xFF, 0x0F, 0x00);
                    AddCode(daddr);
                    AddCode(saddr);

                    return Result.OK;
                }
                else if (src.type == RegType.CHAR || src.type == RegType.INT)
                {
                    AddCode(0xFF, 0x0B, 0x00);
                    AddCode(daddr);
                    AddCode((int)src.data);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".cmp", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;

                bool dt = dst.type == RegType.STR && VerifyTag((string)dst.data);
                bool st = src.type == RegType.STR && VerifyTag((string)src.data);

                if (dt && !ParseTag(((string)dst.data)[1..^1], out int d))
                    return Result.ERR;
                if (st && !ParseTag(((string)src.data)[1..^1], out int s))
                    return Result.ERR;

                if (!dt && (dst.type == RegType.CHAR || dst.type == RegType.INT))
                    d = (int)dst.data;
                else return Result.ERR;
                if (!st && (src.type == RegType.CHAR || src.type == RegType.INT))
                    s = (int)src.data;
                else return Result.ERR;

                AddCode(0x1F, 0x11 | (dt ? 0x02 : 0x00) | (st ? 0x04 : 0x00), 0x00);
                AddCode(d);
                AddCode(s);

                return Result.OK;
            });

            funcList.Add(".jg", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!jumpMap.ContainsKey((string)dst.data))
                        return Result.ERR;
                    AddCode(0x27, 0x11, 0x00);
                    AddCode(jumpMap[(string)dst.data]);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".jl", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!jumpMap.ContainsKey((string)dst.data))
                        return Result.ERR;
                    AddCode(0x47, 0x11, 0x00);
                    AddCode(jumpMap[(string)dst.data]);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".jz", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!jumpMap.ContainsKey((string)dst.data))
                        return Result.ERR;
                    AddCode(0x67, 0x11, 0x00);
                    AddCode(jumpMap[(string)dst.data]);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".loop", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src == null) return Result.ERR;
                if (ext == null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;
                if (!ParseTag(((string)dst.data)[1..^1], out int cnt_addr))
                    return Result.ERR;

                if (src.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)src.data)) return Result.ERR;
                if (!jumpMap.ContainsKey((string)src.data))
                    return Result.ERR;

                if (ext.type == RegType.CHAR || ext.type == RegType.INT)
                {
                    AddCode(0x9F, 0x13, (int)ext.data);
                    AddCode(cnt_addr);
                    AddCode(jumpMap[(string)src.data]);

                    return Result.OK;
                }

                return Result.ERR;
            });

            funcList.Add(".rst", (dst, src, ext) =>
            {
                if (dst != null) return Result.ERR;
                if (src != null) return Result.ERR;

                AddCode(0xA1, 0x10, 0x00);
                return Result.OK;
            });

            funcList.Add(".in", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type != RegType.STR) return Result.ERR;
                if (!VerifyTag((string)dst.data)) return Result.ERR;

                if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                    return Result.ERR;

                AddCode(0xC7, 0x13, 0x00);
                AddCode(daddr);

                return Result.OK;
            });

            funcList.Add(".out", (dst, src, ext) =>
            {
                if (dst == null) return Result.ERR;
                if (src != null) return Result.ERR;

                if (dst.type == RegType.STR && VerifyTag((string)dst.data))
                {
                    if (!ParseTag(((string)dst.data)[1..^1], out int daddr))
                        return Result.ERR;

                    AddCode(0xE7, 0x13, 0x00);
                    AddCode(daddr);

                    return Result.OK;
                }
                else if (dst.type == RegType.CHAR || dst.type == RegType.INT)
                {
                    AddCode(0xE7, 0x11, 0x00);
                    AddCode((int)dst.data);

                    return Result.OK;
                }

                return Result.ERR;
            });
        }

        protected override void LoadParamList()
        {
            base.LoadParamList();
        }
    }
}
