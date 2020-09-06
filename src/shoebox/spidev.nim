import strformat

from posix import nil


var
  SPI_IOC_RD_MODE* {.importc: "SPI_IOC_RD_MODE", header: "<linux/spi/spidev.h>"}: uint
  SPI_IOC_WR_MODE* {.importc: "SPI_IOC_WR_MODE", header: "<linux/spi/spidev.h>"}: uint
  SPI_IOC_RD_BITS_PER_WORD* {.importc: "SPI_IOC_RD_BITS_PER_WORD", header: "<linux/spi/spidev.h>"}: uint
  SPI_IOC_WR_BITS_PER_WORD* {.importc: "SPI_IOC_WR_BITS_PER_WORD", header: "<linux/spi/spidev.h>"}: uint
  SPI_IOC_RD_MAX_SPEED_HZ* {.importc: "SPI_IOC_RD_MAX_SPEED_HZ", header: "<linux/spi/spidev.h>"}: uint
  SPI_IOC_WR_MAX_SPEED_HZ* {.importc: "SPI_IOC_WR_MAX_SPEED_HZ", header: "<linux/spi/spidev.h>"}: uint


type
  SPIDev* = object
    fd: FileHandle

  SPIDevError* = object of IOError


proc setMode*(a: SPIDev, mode: int) =
  ## Set SPI mode of a SPIDev device.
  if posix.ioctl(a.fd, SPI_IOC_WR_MODE, unsafeAddr mode) < 0:
    raise newException(SPIDevError, fmt"failed to set mode to {mode}")


proc setBitsPerWord*(a: SPIDev, bitsPerWord: int) =
  ## Set bits per word of a SPIDev device.
  if posix.ioctl(a.fd, SPI_IOC_WR_BITS_PER_WORD, unsafeAddr bitsPerWord) < 0:
    raise newException(SPIDevError, fmt"failed to set bits_per_word to {bitsPerWord}")


proc setMaxSpeedHz*(a: SPIDev, maxSpeedHz: int) =
  ## Set max speed hz of a SPIDev device.
  if posix.ioctl(a.fd, SPI_IOC_WR_MAX_SPEED_HZ, unsafeAddr maxSpeedHz) < 0:
    raise newException(SPIDevError, fmt"failed to set max_speed_hz to {maxSpeedHz}")


proc writeByte*(a: SPIDev, b: byte) =
  ## Write a single byte to SPIDev.
  discard posix.write(a.fd, unsafeAddr b, 1)


proc close*(a: SPIDev) =
  ## Close a SPIDev.
  discard posix.close(a.fd)


proc newSPIDev*(bus: int, device: int): SPIDev =
  ## Setup a SPIDev with the given bus and device ID.
  var spiFd: FileHandle
  var path = fmt"/dev/spidev{bus}.{device}"

  spiFd = posix.open(path, posix.O_RDWR)
  if spiFd < 0:
    raise newException(SPIDevError, fmt"failed to open {path}")

  return SPIDev(fd: spiFd)
