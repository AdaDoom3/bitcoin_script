with Interfaces; use Interfaces;

package Bitcoin is

  subtype Byte is Unsigned_8;
  type Byte_Array is array (Positive range <>) of aliased Byte;

end;
