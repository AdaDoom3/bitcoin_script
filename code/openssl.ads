with Interfaces;

package OpenSSL is

  subtype Byte is Interfaces.Unsigned_8;
  type Byte_Array is array (Positive range <>) of aliased Byte;

end;
