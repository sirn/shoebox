# Minimal port of Python RPi.GPIO
# https://sourceforge.net/p/raspberry-gpio-python/

import system

from posix import nil


const
  GPIOBaseOffset = 0x200000

  FSelOffset = 0
  SetOffset = 7
  ClrOffset = 10
  PinlevelOffset = 13
  PullUpdnOffset = 37
  PullUpdnClkOffset = 38

  PullUpdnOffset27110 = 57
  PullUpdnOffset27113 = 60

  PageSize = 4*1024
  BlockSize = 4*1024


type
  GPIO* = object
    gpioMap: pointer
    gpioAry: ptr UncheckedArray[uint32]

  GPIOPull* = enum
    off,
    down,
    up

  GPIODir* = enum
    output = 0,
    input = 1,
    alt0 = 4

  GPIOValue* = enum
    low,
    high

  GPIOError* = object of IOError


proc shortWait() =
  for i in 0..150:
    asm "nop"


proc newGPIO*(): GPIO =
  ## Setup and detect GPIO, starting with /dev/gpiomem or fallback to
  ## /dev/mem. /dev/gpiomem can be configured to be run with user
  ## privileges, while /dev/mem always requires root.
  var gpioMap {.volatile.}: pointer
  var gpioAry: ptr UncheckedArray[uint32]

  var periBase: uint32
  var gpioBase: uint32
  var memFd: cint
  var buf: array[4, byte]
  var fp: File

  # Try /dev/gpiomem first, this can be configured to not require root.
  memFd = posix.open("/dev/gpiomem", posix.O_RDWR or posix.O_SYNC)
  if memFd > 0:
    gpioMap = posix.mmap(
      nil,
      BlockSize,
      posix.PROT_READ or posix.PROT_WRITE,
      posix.MAP_SHARED,
      memFd,
      0
    )
    if gpioMap == posix.MAP_FAILED:
      raise newException(GPIOError, "failed to mmap /dev/gpiomem")
    defer:
      discard posix.close(memFd)

    gpioAry = cast[ptr UncheckedArray[uint32]](gpioMap)
    return GPIO(
      gpioMap: gpioMap,
      gpioAry: gpioAry
    )

  # Fallback to /dev/mem; detect peripherals base address
  # using /proc/device-tree/soc/ranges. Usually this returns
  # 0x20000000 for RPi 1 and 0x3F000000 for RPi 2/3.
  try:
    fp = open("/proc/device-tree/soc/ranges", fmRead)
    fp.setFilePos(4, FileSeekPos.fspSet)
    if fp.readBytes(buf, 0, len(buf)) == len(buf):
      periBase = (
        uint32(buf[0]) shl 24 or
        uint32(buf[1]) shl 16 or
        uint32(buf[2]) shl 8 or
        uint32(buf[3]) shl 0)
  except IOError:
    discard
  finally:
    close(fp)

  # Original raspberry-gpio-python also uses /proc/cpuinfo and matches
  # chipset model to set periBase based on a known value. This is unreliable
  # in case the kernel wasn't patched to display BCM2708/2709/2835/2836
  # (e.g. any non-Raspbian kernels).
  #
  # We just fail fast here to save some headaches down the road.
  #
  # See: https://www.raspberrypi.org/forums/viewtopic.php?p=1188136#p1188136
  if periBase == 0:
    raise newException(GPIOError, "unable to detect peripherals base address")

  gpioBase = periBase + GPIOBaseOffset

  # Setup mmap using /dev/mem directly. This is a huge security issue.
  # Send your angry mail to Broadcom.
  memFd = posix.open("/dev/mem", posix.O_RDWR or posix.O_SYNC)
  if memFd < 0:
    raise newException(GPIOError, "failed to open /dev/mem")

  var gpioMem = alloc(BlockSize + (PageSize - 1))
  if gpioMem == nil:
    raise newException(GPIOError, "failed to allocate GPIO memory")

  if cast[ByteAddress](gpioMem) mod PageSize != 0:
    gpioMem = cast[pointer](
      cast[ByteAddress](gpioMem) +
      (PageSize - (cast[ByteAddress](gpioMem) mod PageSize))
    )

  gpioMap = posix.mmap(
    gpioMem,
    BlockSize,
    posix.PROT_READ or posix.PROT_WRITE,
    posix.MAP_SHARED or posix.MAP_FIXED,
    memFd,
    cast[ByteAddress](gpioBase)
  )
  if gpioMap == posix.MAP_FAILED:
    raise newException(GPIOError, "failed to mmap GPIO memory")

  gpioAry = cast[ptr UncheckedArray[uint32]](gpioMap)
  return GPIO(
    gpioMap: gpioMap,
    gpioAry: gpioAry
  )


proc set_pullupdn*(a: GPIO, gpio: int, pud: GPIOPull) =
  ## Configure the pull-up/down resistors of the given pin.
  ##
  ## When `pud` is set to `GPIOPull.up`, the pin have `GPIOValue.value` as
  ## its default state and changed to `GPIOValue.low` when the action is
  ## performed (e.g. pressing a button). Setting `pud` to `GPIOPull.down`
  ## will have the opposite behavior.
  if a.gpioAry[PullUpdnOffset27113] != 0x6770696f:
    var pullReg: uint32 = PullUpdnOffset27110 + uint32(gpio shr 4)
    var pullShift: uint32 = uint32(gpio and 0xf) shl 1'u32
    var tmp: uint32 = a.gpioAry[pullReg]
    var pull: uint32 = 0

    case pud:
      of GPIOPull.up:
        pull = 1
      of GPIOPull.down:
        pull = 2
      else:
        pull = 0

    tmp = tmp and not (3'u32 shl pullShift)
    tmp = tmp or (pull shl pullShift)
    a.gpioAry[pullReg] = tmp

  # Raspberry Pi 3 or lower
  else:
    var clkOffset: uint32 = PullUpdnClkOffset + uint32(gpio div 32)
    var shift: uint32 = uint32(gpio mod 32)
    var tmp: uint32 = a.gpioAry[PullUpdnOffset]

    case pud:
      of GPIOPull.up:
        tmp = (tmp and not 3'u32) or GPIOPull.up.uint32
      of GPIOPull.down:
        tmp = (tmp and not 3'u32) or GPIOPull.down.uint32
      else:
        tmp = tmp and not 3'u32

    a.gpioAry[PullUpdnOffset] = tmp
    shortWait()
    a.gpioAry[clkOffset] = uint32(1 shl shift)
    shortWait()

    a.gpioAry[PullUpdnOffset] = a.gpioAry[PullUpdnOffset] and not 3'u32
    a.gpioAry[clkOffset] = 0


proc setDirection*(a: GPIO, gpio: int, direction: GPIODir) =
  ## Set the direction of the GPIO pin. This can be either `GPIODir.input`
  ## for reading the value of the pin (e.g. button press) or `GPIODir.output`
  ## for writing to a pin (e.g. manipulating a hardware)
  var offset: uint32 = FSelOffset + uint32(gpio div 10)
  var shift: uint32 = uint32(gpio mod 10) * 3'u32
  var tmp: uint32 = a.gpioAry[offset]

  case direction:
    of GPIODir.output:
      tmp = tmp and not uint32(7 shl shift)
      tmp = tmp or uint32(1 shl shift)
    else:
      tmp = tmp and not uint32(7 shl shift)

  a.gpioAry[offset] = tmp


proc getDirection*(a: GPIO, gpio: int): GPIODir =
  ## Returns the current direction of the given GPIO pin.
  var offset: uint32 = FSelOffset + uint32(gpio div 10)
  var shift: uint32 = uint32(gpio mod 10) * 3'u32
  var tmp: uint32 = a.gpioAry[offset]

  tmp = tmp and uint32(7 shl shift)
  tmp = tmp shr shift
  return GPIODir(tmp)


proc setup*(a: GPIO, gpio: int, direction: GPIODir, pud: GPIOPull) =
  ## Performs setting up both pull-up/down register and direction
  ## of a GPIO pin.
  a.setPullUpdn(gpio, pud)
  a.setDirection(gpio, direction)


proc write*(a: GPIO, gpio: int, value: GPIOValue) =
  ## Writes to GPIO pin. Note this function requires the given
  ## GPIO pin to be set to `DIR_OUT`.
  var offset: uint32
  var shift: uint32 = uint32(gpio mod 32)

  case value:
    of GPIOValue.high:
      offset = SetOffset + uint32(gpio div 32)
    else:
      offset = ClrOffset + uint32(gpio div 32)

  a.gpioAry[offset] = 1'u32 shl shift


proc read*(a: GPIO, gpio: int): GPIOValue =
  ## Read the value of GPIO pin.
  var offset: uint32 = PinlevelOffset + uint32(gpio div 32)
  var mask: uint32 = 1'u32 shl uint32(gpio mod 32)
  if (a.gpioAry[offset] and mask) == 0:
    return GPIOValue.low
  return GPIOValue.high


proc close*(a: GPIO) =
  ## Free the memory allocated to communicate with the GPIO
  ## register. This function should be called on exit.
  discard posix.munmap(a.gpioMap, BlockSize)
