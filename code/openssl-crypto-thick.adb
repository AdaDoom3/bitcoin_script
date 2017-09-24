package body OpenSSL.Crypto.Thick is

  -----------------
  -- Conversions --
  -----------------
  function To_Int is new Ada.Unchecked_Conversion (Source => Elliptical_Curve_Kind, Target => Int);
  function To_Int is new Ada.Unchecked_Conversion (Source => Point_Format_Kind,     Target => Int);
  function To_Int is new Ada.Unchecked_Conversion (Source => Base64_BIO_Flag_Kind,  Target => Int);

  -----------------------------
  -- Controlled Access Types --
  -----------------------------
  procedure Initialize (Item : in out Key_Pair_Type) is begin Item.Ptr := EC_KEY_new_by_curve_name (NID_secp256k1); end;
  procedure Finalize   (Item : in out Key_Pair_Type) is begin EC_KEY_free (Item.Ptr); end;

  procedure Initialize (Item : in out Big_Number_Type) is begin Item.Ptr := BN_new; end;
  procedure Finalize   (Item : in out Big_Number_Type) is begin BN_clear_free (Item.Ptr); end;

  procedure Initialize (Item : in out Big_Number_Context) is begin Item.Ptr := BN_CTX_new; BN_CTX_start (Item.Ptr); end;
  procedure Finalize   (Item : in out Big_Number_Context) is begin BN_CTX_end (Item.Ptr); BN_CTX_free (Item.Ptr); end;

  procedure Initialize (Item : in out Elliptical_Curve_Point; Group : in EC_Group) is begin Item.Ptr := EC_POINT_new (Group); end;
  procedure Finalize   (Item : in out Elliptical_Curve_Point) is begin BN_CTX_end (Item.Ptr); end;

  procedure Initialize (Item : in out Binary_IO_Type; Method : in BIO_METHOD) is begin Item.Ptr := BIO_new (Method); end;
  procedure Finalize   (Item : in out Binary_IO_Type) is begin BIO_free_all (Item.Ptr); end;


  -----------------------
  -- Generate_Key_Pair --
  -----------------------
  procedure Generate_Key_Pair (Key_Pair : in out Key_Pair_Type) is
  begin
    Assert (EC_KEY_generate_key (Key_Pair.Ptr));
  end;

  -----------------------
  -- Derive_Public_Key --
  -----------------------
  procedure Derive_Public_Key (Key_Pair : in out Key_Pair_Type; Private_Key : in Byte_Array) is
    Priv_Key : Big_Number_Type;
    Pub_Key  : Elliptical_Curve_Point;
    Group    : EC_Group;
  begin
    Priv_Key.Ptr := BN_bin2bn (Private_Key'Address, Private_Key'Length, Priv_Key.Ptr);
    Assert (EC_KEY_set_private_key (Key_Pair.Ptr, Priv_Key.Ptr));
    declare
      Context : Big_Number_Context;
    begin
      Group := EC_KEY_get0_group (Key_Pair.Ptr);
      Initialize (Pub_Key, Group);
      Assert (EC_POINT_mul (Group, Pub_Key.Ptr, Priv_Key.Ptr, Null_Address, Null_Address, Context.Ptr));
      Assert (EC_KEY_set_public_key (Key_Pair.Ptr, Pub_Key.Ptr));
    end;
  end;

  ---------------------
  -- Get_Private_Key --
  ---------------------
  procedure Get_Private_Key (Private_Key : in out Big_Number_Type'Class; Key_Pair : in Key_Pair_Type) is
  begin
    Private_Key.Ptr    := EC_KEY_get0_private_key (Key_Pair.Ptr);
    Private_Key.Length := Positive (BN_num_bytes (Private_Key.Ptr));
  end;

  --------------------
  -- Get_Public_Key --
  --------------------
  procedure Get_Public_Key (Public_Key : in out Big_Number_Type'Class; Key_Pair : in Key_Pair_Type; Format : in Point_Format_Kind) is
    Group : EC_Group;
    Point : Elliptical_Curve_Point;
  begin
    Point.Ptr := EC_KEY_get0_public_key (Key_Pair.Ptr);
    declare
      Context : Big_Number_Context;
    begin
      Group := EC_KEY_get0_group (Key_Pair.Ptr);
      Public_Key.Ptr := EC_POINT_point2bn (Group, Point.Ptr, To_Int (Format), Public_Key.Ptr, Context.Ptr);
      Public_Key.Length := Positive (BN_num_bytes (Public_Key.Ptr));
    end;
  end;

  ------------
  -- Length --
  ------------
  function Length (Big_Number : Big_Number_Type) return Positive is (Big_Number.Length);

  -------------------
  -- To_Byte_Array --
  -------------------
  procedure To_Byte_Array (Big_Number : in Big_Number_Type; Output : in out Byte_Array) is
  begin
    Ignore (BN_bn2bin (Big_Number.Ptr, Output'Address));
  end;

  --------------------
  -- Base_64_Encode --
  --------------------
  function Base_64_Encode (Decoded : in Byte_Array) return String is
    b64, mem : Binary_IO_Type;
  begin
    Put_Line ("A");
    Initialize (b64, BIO_f_base64);
    Initialize (mem, BIO_s_mem);
    Put_Line ("B");
    mem.Ptr := BIO_push (b64.Ptr, mem.Ptr);
    Put_Line ("C");
    BIO_set_flags (mem.Ptr, To_Int (No_New_Line)); -- Ignore newlines - write everything in one line
    Put_Line ("D");
    Ignore (BIO_write (mem.Ptr, Decoded'Address, Int (Decoded'Length)));
    Put_Line ("E");
    Ignore (BIO_flush (mem.Ptr));
    Put_Line ("F");
    declare
      C_Str : char_array (1 .. 255);
    begin
      Put_Line ("G");
      Ignore (BIO_get_mem_ptr (mem.Ptr, C_Str'Address));
      Put_Line ("H");
      Ignore (BIO_set_close (mem.Ptr, BIO_NOCLOSE));
      Put_Line ("I");

      return To_Ada (C_Str);
    end;
  end;

  --------------------
  -- Base_64_Decode --
  --------------------
  function Base_64_Decode (Encoded : in String) return Byte_Array is
  begin
  -- int Base64Decode(char* b64message, unsigned char** buffer, size_t* length) { //Decodes a base64 encoded string
  --   BIO *bio, *b64;

  --   size_t len     = strlen(b64input),
  --   size_t padding = 0;

  --   if (b64input[len-1] == '=' && b64input[len-2] == '=') //last two chars are =
  --     padding = 2;
  --   else if (b64input[len-1] == '=') //last char is =
  --     padding = 1;

  --   int decodeLen = (len*3)/4 - padding;

  --   *buffer = (unsigned char*)malloc(decodeLen + 1);
  --   (*buffer)[decodeLen] = '\0';

  --   bio = BIO_new_mem_buf(b64message, -1);
  --   b64 = BIO_new(BIO_f_base64());
  --   bio = BIO_push(b64, bio);

  --   BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL); //Do not use newlines to flush buffer
  --   *length = BIO_read(bio, *buffer, strlen(b64message));
  --   assert(*length == decodeLen); //length should equal decodeLen, else something went horribly wrong
  --   BIO_free_all(bio);

  --   return (0); //success
    return (1 => 16#00#);
  end;

  -------------------
  -- Ignore/Assert --
  -------------------
  procedure Ignore (Result : in Int) is begin null; end;
  procedure Assert (Result : in Int) is begin
    if Result /= 1 then
      declare
        Error_Message : chars_ptr := New_Char_Array ((0 .. 255 => nul));
      begin
        ERR_error_string (ERR_get_error, Error_Message);
        raise Assertion_Failed with Value (Error_Message);
      end;
    end if;
  end;
end;
