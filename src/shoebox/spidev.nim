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
  SpiDev* = object
    fd: FileHandle

  SpiDevError* = object of IOError


proc newSpiDev*(bus: int, device: int): SpiDev =
  var spiFd: FileHandle
  var path = fmt"/dev/spidev{bus}.{device}"

  spiFd = posix.open(path, posix.O_RDWR)
  if spiFd < 0:
    raise newException(SpiDevError, fmt"failed to open {path}")

  return SpiDev(fd: spiFd)


proc setMode*(a: SpiDev, mode: int) =
  if posix.ioctl(a.fd, SPI_IOC_WR_MODE, unsafeAddr mode) < 0:
    raise newException(SpiDevError, fmt"failed to set mode to {mode}")


proc setBitsPerWord*(a: SpiDev, bitsPerWord: int) =
  if posix.ioctl(a.fd, SPI_IOC_WR_BITS_PER_WORD, unsafeAddr bitsPerWord) < 0:
    raise newException(SpiDevError, fmt"failed to set bits_per_word to {bitsPerWord}")


proc setMaxSpeedHz*(a: SpiDev, maxSpeedHz: int) =
  if posix.ioctl(a.fd, SPI_IOC_WR_MAX_SPEED_HZ, unsafeAddr maxSpeedHz) < 0:
    raise newException(SpiDevError, fmt"failed to set max_speed_hz to {maxSpeedHz}")


proc writeByte*(a: SpiDev, b: byte) =
  discard posix.write(a.fd, unsafeAddr b, 1)


proc close*(a: SpiDev) =
  discard posix.close(a.fd)
