MODULE Modules;  (* jt 6.1.96 *)

  (* access to list of modules and commands, based on ETH Oberon *)


  IMPORT SYSTEM, Platform, Heap; (* Note, must import Platform before Heap *)

  CONST
    ModNameLen* = 20;

  TYPE
    ModuleName* = Heap.ModuleName;
    Module*     = Heap.Module;
    Cmd*        = Heap.Cmd;
    Command*    = Heap.Command;
  VAR
    res*:       INTEGER;
    resMsg*:    ARRAY 256 OF CHAR;
    imported*:  ModuleName;
    importing*: ModuleName;

    MainStackFrame-: SYSTEM.ADDRESS;
    ArgCount-:       INTEGER;
    ArgVector-:      SYSTEM.ADDRESS;
    BinaryDir-:      ARRAY 1024 OF CHAR;


(* Program startup *)

  PROCEDURE -ExternInitHeap         "extern void Heap_InitHeap();";
  PROCEDURE -InitHeap               "Heap_InitHeap()";
  PROCEDURE -ExternInitModulesInit  "extern void *Modules__init(void);";
  PROCEDURE -ModulesInit()          "Modules__init()";

  PROCEDURE Init*(argc: SYSTEM.INT32; argvadr: SYSTEM.ADDRESS);
  (* This start code is called by the __INIT macro generated by the compiler
     as the C main program. *)
  BEGIN
    MainStackFrame := argvadr;
    ArgCount := SYSTEM.VAL(INTEGER, argc);
    SYSTEM.GET(argvadr, ArgVector);

    InitHeap;      (* Initialse heap variables needed for compiler generated *__inits *)
    ModulesInit(); (* Our own __init code will run Platform__init and Heap__init. *)
  END Init;


  PROCEDURE GetArg*(n: INTEGER; VAR val: ARRAY OF CHAR);
  TYPE argptr = POINTER TO ARRAY 1024 OF CHAR;
  VAR arg: argptr;
  BEGIN
    IF n < ArgCount THEN
      SYSTEM.GET(ArgVector + n*SIZE(SYSTEM.ADDRESS), arg); (* Address of nth argument. *)
      COPY(arg^, val);
    END
  END GetArg;

  PROCEDURE GetIntArg*(n: INTEGER; VAR val: LONGINT);
  VAR s: ARRAY 64 OF CHAR; k, d, i: LONGINT;
  BEGIN
    s := ""; GetArg(n, s); i := 0;
    IF s[0] = "-" THEN i := 1 END ;
    k := 0; d := ORD(s[i]) - ORD("0");
    WHILE (d >= 0 ) & (d <= 9) DO k := k*10 + d; INC(i); d := ORD(s[i]) - ORD("0") END ;
    IF s[0] = "-" THEN k := -k; DEC(i) END ;
    IF i > 0 THEN val := k END
  END GetIntArg;

  PROCEDURE ArgPos*(s: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER; arg: ARRAY 256 OF CHAR;
  BEGIN
    i := 0; GetArg(i, arg);
    WHILE (i < ArgCount) & (s # arg) DO INC(i); GetArg(i, arg) END ;
    RETURN i
  END ArgPos;


(* Determine directory from which this executable was loaded *)

  PROCEDURE CharCount(s: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER;
  BEGIN
    i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END;
    RETURN i;
  END CharCount;

  PROCEDURE Append(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  VAR i,j: INTEGER;
  BEGIN
    i := 0; j := CharCount(d);
    WHILE s[i] # 0X DO d[j] := s[i]; INC(i); INC(j) END;
    d[j] := 0X;
  END Append;

  PROCEDURE AppendPart(c: CHAR; s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  VAR i,j: INTEGER;
  BEGIN
    i := 0; j := CharCount(d);
    (* Append delimiter c to d only if d is either empty or doesn not
       already end in c. *)
    IF (j > 0) & (d[j-1] # c) THEN d[j] := c; INC(j) END;
    (* Append s to d *)
    WHILE s[i] # 0X DO d[j] := s[i]; INC(i); INC(j) END;
    d[j] := 0X;
  END AppendPart;

  PROCEDURE IsOneOf(c: CHAR; s: ARRAY OF CHAR): BOOLEAN;
  VAR i: INTEGER;
  BEGIN
    IF c = 0X THEN RETURN FALSE END;
    i := 0; WHILE (s[i] # c) & (s[i] # 0X) DO INC(i) END;
    RETURN s[i] = c
  END IsOneOf;

  PROCEDURE IsAbsolute(d: ARRAY OF CHAR): BOOLEAN;
  BEGIN
    IF d = ''              THEN RETURN FALSE END;
    IF IsOneOf(d[0], '/\') THEN RETURN TRUE  END;
    IF d[1] = ':'          THEN RETURN TRUE  END;
    RETURN FALSE;
  END IsAbsolute;

  PROCEDURE Canonify(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  BEGIN
    IF IsAbsolute(s) THEN
      COPY(s, d)
    ELSE
      COPY(Platform.CWD, d); AppendPart('/', s, d);
    END;
  END Canonify;

  PROCEDURE IsFilePresent(s: ARRAY OF CHAR): BOOLEAN;
  VAR identity: Platform.FileIdentity;
  BEGIN
    (*Out.String("IsFilePresent("); Out.String(s); Out.String(")."); Out.Ln;*)
    RETURN Platform.IdentifyByName(s, identity) = 0
  END IsFilePresent;

  PROCEDURE ExtractPart(s: ARRAY OF CHAR; VAR i: INTEGER; p: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  (* Extracts from s starting at i up to any character in p.
     Result string in d.
     Returns i skipped passed found string and any number of delimiters from p.
  *)
  VAR j: INTEGER;
  BEGIN
    j := 0;
    WHILE (s[i] # 0X) & ~IsOneOf(s[i], p) DO
      d[j] := s[i]; INC(i); INC(j)
    END;
    d[j] := 0X;
    WHILE IsOneOf(s[i], p) DO INC(i) END
  END ExtractPart;

  PROCEDURE Trim(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  (* Remove redundant '.'s and '/'s. Convert '\'s to '/'.
     Note, does not remove 'x/..'. This cannot safely be removed because if
     x is a link then 'x/..' means the parent of what x links to rather than
     the directory containing link x.
  *)
  VAR i,j: INTEGER; part: ARRAY 1024 OF CHAR;
  BEGIN
    i := 0; j := 0;
    (* Retain any leading single or pair of '/' (filesystem root or network root). *)
    WHILE (i<2) & IsOneOf(s[i], "/\") DO INC(i); d[j] := '/'; INC(j) END;
    d[j] := 0X;
    (* Append path parts omitting empty or '.' parts. *)
    WHILE s[i] # 0X DO
      ExtractPart(s, i, "/\", part);
      IF (part # '') & (part # '.') THEN AppendPart('/', part, d) END
    END;
  END Trim;

  PROCEDURE FindBinaryDir(VAR binarydir: ARRAY OF CHAR);
  TYPE pathstring = ARRAY 4096 OF CHAR;
  VAR
    arg0:       pathstring;  (* The command exactly as passed by the shell *)
    pathlist:   pathstring;  (* The whole PATH environment variable *)
    pathdir:    pathstring;  (* A single directory from the PATH *)
    tempstr:    pathstring;
    i, j, k:    INTEGER;
    present:    BOOLEAN;
  BEGIN
    IF ArgCount < 1 THEN
      (* The caller is misbehaving: Shells and GUIs always pass the command
         as ARGV[0]. *)
      binarydir[0] := 0X;
      RETURN;
    END;

    GetArg(0, arg0); (* arg0 is the command binary file name passed by the shell. *)
    i := 0; WHILE (arg0[i] # 0X) & (arg0[i] # '/') & (arg0[i] # '\') DO INC(i) END;
    IF (arg0[i] = '/') OR (arg0[i] = '\') THEN
      (* The argument contains a '/', we expect it to work without reference
         to the path. *)
      Trim(arg0, tempstr); Canonify(tempstr, binarydir);
      present := IsFilePresent(binarydir)
    ELSE
      (* There are no '/'s in arg0, so search through the path. *)
      Platform.GetEnv("PATH", pathlist);
      i := 0; present := FALSE;
      WHILE (~present) & (pathlist[i] # 0X) DO
        ExtractPart(pathlist, i, ":;", pathdir);
        AppendPart('/', arg0, pathdir);
        Trim(pathdir, tempstr); Canonify(tempstr, binarydir);
        present := IsFilePresent(binarydir)
      END
    END;

    IF present THEN
      (* Remove trailing binarydir file name *)
      k := CharCount(binarydir);
      WHILE (k > 0) & ~IsOneOf(binarydir[k-1], '/\') DO DEC(k) END;
      (* Chop off binarydir file name *)
      IF k = 0 THEN binarydir[k] := 0X ELSE binarydir[k-1] := 0X END;
    ELSE
      binarydir[0] := 0X (* Couldn't determine binary directory. *)
    END
  END FindBinaryDir;


(* Module and command lookup by name *)

  PROCEDURE -modules(): Module     "(Heap_Module)Heap_modules";
  (*PROCEDURE -setmodules(m: Module) "Heap_modules = m";*)

  PROCEDURE ThisMod* (name: ARRAY OF CHAR): Module;
    VAR m: Module; bodyname: ARRAY 64 OF CHAR; body: Command;
  BEGIN m := modules();
    WHILE (m # NIL) & (m.name # name) DO m := m.next END ;
    IF m # NIL THEN res := 0; resMsg := ""
    ELSE res := 1; COPY(name, importing);
      resMsg := ' module "'; Append(name, resMsg); Append('" not found', resMsg);
    END ;
    RETURN m
  END ThisMod;

  PROCEDURE ThisCommand* (mod: Module; name: ARRAY OF CHAR): Command;
    VAR c: Cmd;
  BEGIN c := mod.cmds;
    WHILE (c # NIL) & (c.name # name) DO c := c.next END ;
    IF c # NIL THEN res := 0; resMsg := ""; RETURN c.cmd
    ELSE res := 2; resMsg := ' command "'; COPY(name, importing);
      Append(mod.name, resMsg); Append(".", resMsg); Append(name, resMsg); Append('" not found', resMsg);
      RETURN NIL
    END
  END ThisCommand;

  PROCEDURE Free*(name: ARRAY OF CHAR; all: BOOLEAN);
    VAR m, p: Module; refcount: LONGINT;
  BEGIN m := modules();
    IF all THEN
      res := 1; resMsg := 'unloading "all" not yet supported'
    ELSE
      refcount := Heap.FreeModule(name);
      IF refcount = 0 THEN
        res := 0
      ELSE
        IF refcount < 0 THEN resMsg := "module not found"
        ELSE resMsg := "clients of this module exist"
        END;
        res := 1
      END
    END
  END Free;



  (* Run time error reporting. *)

  PROCEDURE errch(c: CHAR);  (* Here we favour simplicity over efficiency, so no buffering. *)
  VAR e: Platform.ErrorCode;
  BEGIN e := Platform.Write(Platform.StdOut, SYSTEM.ADR(c), 1)
  END errch;

  PROCEDURE errstring(s: ARRAY OF CHAR);
  VAR i: LONGINT;
  BEGIN
    i := 0; WHILE (i<LEN(s)) & (s[i] # 0X) DO errch(s[i]); INC(i) END
  END errstring;

  PROCEDURE errint(l: SYSTEM.INT32);
  BEGIN
    IF l <  0  THEN errch('-'); l := -l END;
    IF l >= 10 THEN errint(l DIV 10) END;
    errch(CHR(l MOD 10 + 30H))
  END errint;

  PROCEDURE DisplayHaltCode(code: SYSTEM.INT32);
  BEGIN
    CASE code OF
    | -1: errstring("Assertion failure.")
    | -2: errstring("Index out of range.")
    | -3: errstring("Reached end of function without reaching RETURN.")
    | -4: errstring("CASE statement: no matching label and no ELSE.")
    | -5: errstring("Type guard failed.")
    | -6: errstring("Implicit type guard in record assignment failed.")
    | -7: errstring("Invalid case in WITH statement.")
    | -8: errstring("Value out of range.")
    | -9: errstring("Heap interrupted while locked, but lockdepth = 0 at unlock.")
    |-10: errstring("NIL access.");
    |-11: errstring("Alignment error.");
    |-12: errstring("Divide by zero.");
    |-13: errstring("Arithmetic overflow/underflow.");
    |-14: errstring("Invalid function argument.");
    |-15: errstring("Internal error, e.g. Type descriptor size mismatch.")
    |-20: errstring("Too many, or negative number of, elements in dynamic array.")
    ELSE
    END
  END DisplayHaltCode;

  PROCEDURE Halt*(code: SYSTEM.INT32);
  BEGIN
    Heap.FINALL;
    errstring("Terminated by Halt("); errint(code); errstring("). ");
    IF code < 0 THEN DisplayHaltCode(code) END;
    errstring(Platform.NL);
    Platform.Exit(code);
  END Halt;

  PROCEDURE AssertFail*(code: SYSTEM.INT32);
  BEGIN
    Heap.FINALL;
    errstring("Assertion failure.");
    IF code # 0 THEN errstring(" ASSERT code "); errint(code); errstring("."); END;
    errstring(Platform.NL);
    IF code > 0 THEN Platform.Exit(code) ELSE Platform.Exit(-1) END;
  END AssertFail;

BEGIN
  FindBinaryDir(BinaryDir);
END Modules.
