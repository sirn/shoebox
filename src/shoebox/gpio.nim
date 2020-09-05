# Minimal port of Python RPi.GPIO
# https://sourceforge.net/p/raspberry-gpio-python/

import system

from posix import nil

const
  GPIO_BASE_OFFSET = 0x200000

const
  SETUP_OK* = 0
  SETUP_DEVMEM_FAIL* = 1
  SETUP_MALLOC_FAIL* = 2
  SETUP_MMAP_FAIL* = 3
  SETUP_NOT_RPI_FAIL* = 5

const
  FSEL_OFFSET = 0
  SET_OFFSET = 7
  CLR_OFFSET = 10
  PINLEVEL_OFFSET = 13
  PULLUPDN_OFFSET = 37
  PULLUPDNCLK_OFFSET = 38

const
  PULLUPDN_OFFSET_2711_0 = 57
  PULLUPDN_OFFSET_2711_3 = 60

const
  PAGE_SIZE = 4*1024
  BLOCK_SIZE = 4*1024

const
  DIR_IN* = 1
  DIR_OUT* = 0
  DIR_ALT0* = 4

const
  PUD_OFF* = 0
  PUD_DOWN* = 1
  PUD_UP* = 2

const
  HIGH* = 1
  LOW* = 0


var
  gpio_map {.volatile.}: pointer
  gpio_ary {.volatile.}: ptr UncheckedArray[uint32]


proc short_wait() =
  for i in 0..150:
    asm "nop"


proc setup*(): int =
  ## Setup and detect GPIO, starting with /dev/gpiomem or fallback to
  ## /dev/mem. /dev/gpiomem can be configured to be run with user
  ## privileges, while /dev/mem always requires root.
  var peri_base: uint32
  var gpio_base: uint32
  var mem_fd: cint
  var buf: array[4, byte]
  var fp: File

  # Try /dev/gpiomem first, this can be configured to not require root.
  mem_fd = posix.open("/dev/gpiomem", posix.O_RDWR or posix.O_SYNC)
  if mem_fd > 0:
    gpio_map = posix.mmap(
      nil,
      BLOCK_SIZE,
      posix.PROT_READ or posix.PROT_WRITE,
      posix.MAP_SHARED,
      mem_fd,
      0
    )
    if gpio_map == posix.MAP_FAILED:
      return SETUP_MMAP_FAIL
    defer:
      discard posix.close(mem_fd)

    gpio_ary = cast[ptr UncheckedArray[uint32]](gpio_map)
    return SETUP_OK

  # Fallback to /dev/mem; detect peripherals base address
  # using /proc/device-tree/soc/ranges. Usually this returns
  # 0x20000000 for RPi 1 and 0x3F000000 for RPi 2/3.
  try:
    fp = open("/proc/device-tree/soc/ranges", fmRead)
    fp.setFilePos(4, FileSeekPos.fspSet)
    if fp.readBytes(buf, 0, len(buf)) == len(buf):
      peri_base = (
        uint32(buf[0]) shl 24 or
        uint32(buf[1]) shl 16 or
        uint32(buf[2]) shl 8 or
        uint32(buf[3]) shl 0)
  except IOError:
    discard
  finally:
    close(fp)

  # Original raspberry-gpio-python also uses /proc/cpuinfo and matches
  # chipset model to set peri_base based on a known value. This is unreliable
  # in case the kernel wasn't patched to display BCM2708/2709/2835/2836
  # (e.g. any non-Raspbian kernels).
  #
  # We just fail fast here to save some headaches down the road.
  #
  # See: https://www.raspberrypi.org/forums/viewtopic.php?p=1188136#p1188136
  if peri_base == 0:
    return SETUP_NOT_RPI_FAIL

  gpio_base = peri_base + GPIO_BASE_OFFSET

  # Setup mmap using /dev/mem directly. This is a huge security issue.
  # Send your angry mail to Broadcom.
  mem_fd = posix.open("/dev/mem", posix.O_RDWR or posix.O_SYNC)
  if mem_fd < 0:
    return SETUP_DEVMEM_FAIL

  var gpio_mem = alloc(BLOCK_SIZE + (PAGE_SIZE - 1))
  if gpio_mem == nil:
    return SETUP_MALLOC_FAIL

  if cast[ByteAddress](gpio_mem) mod PAGE_SIZE != 0:
    gpio_mem = cast[pointer](
      cast[ByteAddress](gpio_mem) +
      (PAGE_SIZE - (cast[ByteAddress](gpio_mem) mod PAGE_SIZE))
    )

  gpio_map = posix.mmap(
    gpio_mem,
    BLOCK_SIZE,
    posix.PROT_READ or posix.PROT_WRITE,
    posix.MAP_SHARED or posix.MAP_FIXED,
    mem_fd,
    cast[ByteAddress](gpio_base)
  )
  if gpio_map == posix.MAP_FAILED:
    return SETUP_MMAP_FAIL

  gpio_ary = cast[ptr UncheckedArray[uint32]](gpio_map)
  return SETUP_OK


proc set_pullupdn*(gpio: int, pud: int) =
  ## Configure the pull-up/down resistors of the given pin.
  ##
  ## When `pud` is set to `PUD_UP`, the pin have `HIGH` as its default state
  ## and changed to `LOW` when the action is performed (e.g. pressing a button).
  ## Setting `pud` to `PUD_DOWN` will have the opposite behavior.
  if gpio_ary[PULLUPDN_OFFSET_2711_3] != 0x6770696f:
    var pull_reg: uint32 = PULLUPDN_OFFSET_2711_0 + uint32(gpio shr 4)
    var pull_shift: uint32 = uint32(gpio and 0xf) shl 1'u32
    var tmp: uint32 = gpio_ary[pull_reg]
    var pull: uint32 = 0

    case pud:
      of PUD_UP:
        pull = 1
      of PUD_DOWN:
        pull = 2
      else:
        pull = 0

    tmp = tmp and not (3'u32 shl pull_shift)
    tmp = tmp or (pull shl pull_shift)
    gpio_ary[pull_reg] = tmp

  # Raspberry Pi 3 or lower
  else:
    var clk_offset: uint32 = PULLUPDNCLK_OFFSET + uint32(gpio div 32)
    var shift: uint32 = uint32(gpio mod 32)
    var tmp: uint32 = gpio_ary[PULLUPDN_OFFSET]

    case pud:
      of PUD_UP:
        tmp = (tmp and not 3'u32) or PUD_UP
      of PUD_DOWN:
        tmp = (tmp and not 3'u32) or PUD_DOWN
      else:
        tmp = tmp and not 3'u32

    gpio_ary[PULLUPDN_OFFSET] = tmp
    short_wait()
    gpio_ary[clk_offset] = uint32(1 shl shift)
    short_wait()

    gpio_ary[PULLUPDN_OFFSET] = gpio_ary[PULLUPDN_OFFSET] and not 3'u32
    gpio_ary[clk_offset] = 0


proc set_direction*(gpio: int, direction: int) =
  ## Set the direction of the GPIO pin. This can be either `DIR_IN` for
  ## reading the value of the pin (e.g. button press) or `DIR_OUT` for
  ## writing (e.g. manipulating a hardware)
  var offset: uint32 = FSEL_OFFSET + uint32(gpio div 10)
  var shift: uint32 = uint32(gpio mod 10) * 3'u32
  var tmp: uint32 = gpio_ary[offset]

  case direction:
    of DIR_OUT:
      tmp = tmp and not uint32(7 shl shift)
      tmp = tmp or uint32(1 shl shift)
    else:
      tmp = tmp and not uint32(7 shl shift)

  gpio_ary[offset] = tmp


proc get_direction*(gpio: int): int =
  ## Returns the current direction of the given GPIO pin.
  var offset: uint32 = FSEL_OFFSET + uint32(gpio div 10)
  var shift: uint32 = uint32(gpio mod 10) * 3'u32
  var tmp: uint32 = gpio_ary[offset]

  tmp = tmp and uint32(7 shl shift)
  tmp = tmp shr shift
  return int(tmp)


proc setup_gpio*(gpio: int, direction: int, pud: int) =
  ## Performs setting up both pull-up/down register and direction
  ## of a GPIO pin.
  set_pullupdn(gpio, pud)
  set_direction(gpio, direction)


proc output_gpio*(gpio: int, value: int) =
  ## Writes to GPIO pin. Note this function requires the given
  ## GPIO pin to be set to `DIR_OUT`.
  var offset: uint32
  var shift: uint32 = uint32(gpio mod 32)

  case value:
    of HIGH:
      offset = SET_OFFSET + uint32(gpio div 32)
    else:
      offset = CLR_OFFSET + uint32(gpio div 32)

  gpio_ary[offset] = 1'u32 shl shift


proc input_gpio*(gpio: int): int =
  ## Read the value of GPIO pin.
  var offset: uint32 = PINLEVEL_OFFSET + uint32(gpio div 32)
  var mask: uint32 = 1'u32 shl uint32(gpio mod 32)
  if (gpio_ary[offset] and mask) == 0:
    return LOW
  return HIGH


proc cleanup*() =
  ## Free the memory allocated to communicate with the GPIO
  ## register. This function should be called on exit.
  discard posix.munmap(gpio_map, BLOCK_SIZE)
