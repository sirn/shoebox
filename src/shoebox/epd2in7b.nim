import os
import algorithm
import strformat

import gpio
import spidev


type
  Epd2in7b* = object
    gpio*: GPIO
    spiDev*: SPIDev

  EpdColor* = enum
    ecBlack,
    ecRed

  EpdPin* = enum
    epBtn1 = 5,
    epBtn2 = 6,
    epCs = 8,
    epBtn3 = 13,
    epRst = 17,
    epBtn4 = 19,
    epBusy = 24,
    epDc = 25

  EpdError* = object of IOError


const
  EpdWidth* = 176
  EpdHeight* = 264
  EpdMaxSize* = int(EpdWidth * EpdHeight / 8)


type
  EpdFb* = openarray[uint8]


const
  PanelSetting = 0x00
  PowerSetting = 0x01
  PowerOff = 0x02
  PowerOffSequenceSetting = 0x03
  PowerOn = 0x04
  BoosterSoftStart = 0x06
  DeepSleep = 0x07
  DataStartTransmission1 = 0x10
  DisplayRefresh = 0x12
  DataStartTransmission2 = 0x13
  PartialDataStartTransmission1 = 0x14
  PartialDataStartTransmission2 = 0x15
  PartialDisplayRefresh = 0x16
  LutForVcom = 0x20
  LutWhiteToWhite = 0x21
  LutBlackToWhite = 0x22
  LutWhiteToBlack = 0x23
  LutBlackToBlack = 0x24
  PllControl = 0x30
  VcomAndDataIntervalSetting = 0x50
  TconResolution = 0x61
  VcmDcSettingRegister = 0x82
  PowerOptimization = 0xF8

  LutVcomDc = [
    0x00'u8, 0x00'u8,
    0x00'u8, 0x1A'u8, 0x1A'u8, 0x00'u8, 0x00'u8, 0x01'u8,
    0x00'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x00'u8, 0x0E'u8, 0x01'u8, 0x0E'u8, 0x01'u8, 0x10'u8,
    0x00'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x00'u8, 0x04'u8, 0x10'u8, 0x00'u8, 0x00'u8, 0x05'u8,
    0x00'u8, 0x03'u8, 0x0E'u8, 0x00'u8, 0x00'u8, 0x0A'u8,
    0x00'u8, 0x23'u8, 0x00'u8, 0x00'u8, 0x00'u8, 0x01'u8
  ]

  # R21H
  LutWw = [
    0x90'u8, 0x1A'u8, 0x1A'u8, 0x00'u8, 0x00'u8, 0x01'u8,
    0x40'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x84'u8, 0x0E'u8, 0x01'u8, 0x0E'u8, 0x01'u8, 0x10'u8,
    0x80'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x00'u8, 0x04'u8, 0x10'u8, 0x00'u8, 0x00'u8, 0x05'u8,
    0x00'u8, 0x03'u8, 0x0E'u8, 0x00'u8, 0x00'u8, 0x0A'u8,
    0x00'u8, 0x23'u8, 0x00'u8, 0x00'u8, 0x00'u8, 0x01'u8
  ]

  # R22H    r
  LutBw = [
    0xA0'u8, 0x1A'u8, 0x1A'u8, 0x00'u8, 0x00'u8, 0x01'u8,
    0x00'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x84'u8, 0x0E'u8, 0x01'u8, 0x0E'u8, 0x01'u8, 0x10'u8,
    0x90'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0xB0'u8, 0x04'u8, 0x10'u8, 0x00'u8, 0x00'u8, 0x05'u8,
    0xB0'u8, 0x03'u8, 0x0E'u8, 0x00'u8, 0x00'u8, 0x0A'u8,
    0xC0'u8, 0x23'u8, 0x00'u8, 0x00'u8, 0x00'u8, 0x01'u8
  ]

  # R23H    w
  LutBb = [
    0x90'u8, 0x1A'u8, 0x1A'u8, 0x00'u8, 0x00'u8, 0x01'u8,
    0x40'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x84'u8, 0x0E'u8, 0x01'u8, 0x0E'u8, 0x01'u8, 0x10'u8,
    0x80'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x00'u8, 0x04'u8, 0x10'u8, 0x00'u8, 0x00'u8, 0x05'u8,
    0x00'u8, 0x03'u8, 0x0E'u8, 0x00'u8, 0x00'u8, 0x0A'u8,
    0x00'u8, 0x23'u8, 0x00'u8, 0x00'u8, 0x00'u8, 0x01'u8
  ]

  # R24H    b
  LutWb = [
    0x90'u8, 0x1A'u8, 0x1A'u8, 0x00'u8, 0x00'u8, 0x01'u8,
    0x20'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x84'u8, 0x0E'u8, 0x01'u8, 0x0E'u8, 0x01'u8, 0x10'u8,
    0x10'u8, 0x0A'u8, 0x0A'u8, 0x00'u8, 0x00'u8, 0x08'u8,
    0x00'u8, 0x04'u8, 0x10'u8, 0x00'u8, 0x00'u8, 0x05'u8,
    0x00'u8, 0x03'u8, 0x0E'u8, 0x00'u8, 0x00'u8, 0x0A'u8,
    0x00'u8, 0x23'u8, 0x00'u8, 0x00'u8, 0x00'u8, 0x01'u8
  ]


proc sendCmd(a: Epd2in7b, command: uint8) =
  a.gpio.write(EpdPin.epDc.int, GPIOVal.gvLow)
  a.spiDev.writeByte(byte(command))


proc sendData(a: Epd2in7b, command: uint8) =
  a.gpio.write(EpdPin.epDc.int, GPIOVal.gvHigh)
  a.spiDev.writeByte(byte(command))


template sendCmdData(a: Epd2in7b, command: uint8, data: varargs[uint8]) =
  a.sendCmd(command)
  for d in data:
    a.sendData(d)


proc wait*(a: Epd2in7b) =
  ## Wait until chipset becomes ready.
  while a.gpio.read(EpdPin.epBusy.int) == GPIOVal.gvLow:
    sleep(100)


proc powerOff*(a: Epd2in7b) =
  ## Turn off the chipset.
  sendCmdData(a, PowerOff)
  sendCmdData(a, PowerOffSequenceSetting, 0x00)
  a.wait()


proc deepSleep*(a: Epd2in7b) =
  ## Put the chipset in deep sleep mode to save power.
  sendCmdData(a, DeepSleep, 0xa5)


proc displayRefresh*(a: Epd2in7b) =
  ## Perform a full display refresh.
  sendCmdData(a, DisplayRefresh)
  a.wait()


proc displayRefreshPartial*(a: Epd2in7b, x: int, y: int, width: int, height: int) =
  ## Perform a partial display refresh originating at `(x, y)` coordinates for
  ## the given `width` and `height`. `x` coordinate and `width` must be
  ## dividable by 8 (but not `y` and `height`).
  sendCmdData(
    a,
    PartialDisplayRefresh,
    0x00 and uint8(x shr 8), # DFV_EN & WIDTH
    uint8(x and 0xF8),
    uint8(y shr 8),
    uint8(y and 0xFF),
    uint8(width shr 8),
    uint8(width and 0xF8),
    uint8(height shr 8),
    uint8(height and 0xFF)
  )
  a.wait()


proc convertFb*(
  a: Epd2in7b,
  sSeq: openArray[uint8],
  width: int,
  height: int,
  color: EpdColor
): seq[uint8] =
  ## Convert a sequence of uint8 into an EPD framebuffer. When converting
  ## for a full render (via `renderFb`), `width` and `height` must be set
  ## to that of EPD's, not the source image.
  var fb {.noinit.}: seq[uint8]
  var fbSize = int(width * height / 8)

  fb.setLen(fbSize)

  case color:
    of ecBlack:
      # Black fills 0xff (0) -> 0x00 (1)
      fb.fill(0xff)

      for y in 0..(height - 1):
        for x in 0..(width - 1):
          var cd = x + y * width
          if len(sSeq) > cd and sSeq[cd] != 0:
            var pos = int((x + y * width) / 8)
            fb[pos] = fb[pos] and not uint8(0x80 shr (x mod 8))

    of ecRed:
      # Red fills 0x00 (0) -> 0xff (1) (yes this is annoying)
      fb.fill(0x00)

      for y in 0..(height - 1):
        for x in 0..(width - 1):
          var cd = x + y * width
          if len(sSeq) > cd and sSeq[cd] != 0:
            var pos = int((x + y * width) / 8)
            fb[pos] = fb[pos] or uint8(0x80 shr (x mod 8))

  return fb


proc renderFb*(a: Epd2in7b, fb: EpdFb, color: EpdColor) =
  ## Render framebuffer to the given color channel. Note that it
  ## is recommended to invoke `renderFb` in the following order:
  ##
  ##    epd2in7b.setup()
  ##    epd2in7b.renderFb(blackFb, EpdColor.ecBlack)
  ##    epd2in7b.renderFb(redFb, EpdColor.ecBlack)
  ##    epd2in7b.displayRefresh()
  ##    epd2in7b.deepSleep()
  ##
  case color:
    of ecBlack:
      a.sendCmd(DataStartTransmission1)
    of ecRed:
      a.sendCmd(DataStartTransmission2)
  sleep(2)
  for i in 0..(len(fb) - 1):
    a.sendData(fb[i] and 0xff)
  sleep(2)


proc renderFbPartial*(
  a: Epd2in7b,
  fb: EpdFb,
  x: int,
  y: int,
  width: int,
  height: int,
  color: EpdColor
) =
  ## Similar to `renderFb` but only sends partial data originating at
  ## `(x, y)` coordinates for the given `width` and `height`. `x` coordinate
  ## and `width` must be dividable by 8 (but not `y` and `height`).
  if width mod 8 != 0:
    raise newException(
      EpdError,
      fmt"got {width} for width, but must be dividable by 8"
    )
  if x mod 8 != 0:
    raise newException(
      EpdError,
      fmt"got {x} for x, but must be dividable by 8"
    )
  case color:
    of ecBlack:
      a.sendCmd(PartialDataStartTransmission1)
    of ecRed:
      a.sendCmd(PartialDataStartTransmission2)
  a.sendData(uint8(x shr 8))
  a.sendData(uint8(x and 0xF8))
  a.sendData(uint8(y shr 8))
  a.sendData(uint8(y and 0xFF))
  a.sendData(uint8(width shr 8))
  a.sendData(uint8(width and 0xF8))
  a.sendData(uint8(height shr 8))
  a.sendData(uint8(height and 0xFF))
  sleep(2)
  for i in 0..(len(fb) - 1):
    a.sendData(fb[i] and 0xff)
  sleep(2)


proc setup*(a: Epd2in7b) =
  ## Perform an initial setup. This function should be called to wake
  ## up the EPD from deep sleep state or on initial system power up.
  # Note: this sequence is different from the Python implementation; it
  # is based on the 2.7inch-e-paper-b-specification spec.

  # Reset
  a.gpio.write(EpdPin.epRst.int, GPIOVal.gvLow)
  sleep(200)
  a.gpio.write(EpdPin.epRst.int, GPIOVal.gvHigh)
  sleep(200)

  sendCmdData(a, BoosterSoftStart, 0x07, 0x07, 0x17)
  sendCmdData(a, PowerOptimization, 0x60, 0xa5)
  sendCmdData(a, PowerOptimization, 0x89, 0xa5)
  sendCmdData(a, PowerOptimization, 0x90, 0x00)
  sendCmdData(a, PowerOptimization, 0x93, 0x2a)
  sendCmdData(a, PowerOptimization, 0x73, 0x41)
  sendCmdData(a, PartialDisplayRefresh, 0x00)  # Reset DFV_EN
  sendCmdData(a, PowerSetting, 0x03, 0x00, 0x2b, 0x2b, 0x09)
  sendCmdData(a, PowerOn)
  a.wait()

  sendCmdData(a, PanelSetting, 0xaf)
  sendCmdData(a, PllControl, 0x3a)
  sendCmdData(
    a,
    TconResolution,
    uint8(EpdWidth shr 8),
    uint8(EpdWidth and 0xff),
    uint8(EpdHeight shr 8),
    uint8(EpdHeight and 0xff),
  )

  sendCmdData(a, VcmDcSettingRegister, 0x12)
  sendCmdData(a, VcomAndDataIntervalSetting, 0x87)
  sendCmdData(a, LutForVcom, LutVcomDc)
  sendCmdData(a, LutWhiteToWhite, LutWw)
  sendCmdData(a, LutBlackToWhite, LutBw)
  sendCmdData(a, LutWhiteToBlack, LutWb)
  sendCmdData(a, LutBlackToBlack, LutBb)


proc newEpd2in7b*(gpio: GPIO, spiDev: SPIDev): Epd2in7b =
  gpio.setup(EpdPin.epBtn1.int, GPIODir.gdInput, GPIOPull.gpUp)
  gpio.setup(EpdPin.epBtn2.int, GPIODir.gdInput, GPIOPull.gpUp)
  gpio.setup(EpdPin.epBtn3.int, GPIODir.gdInput, GPIOPull.gpUp)
  gpio.setup(EpdPin.epBtn4.int, GPIODir.gdInput, GPIOPull.gpUp)

  gpio.setup(EpdPin.epBusy.int, GPIODir.gdInput, GPIOPull.gpOff)
  gpio.setup(EpdPin.epRst.int, GPIODir.gdOutput, GPIOPull.gpOff)
  gpio.setup(EpdPin.epDc.int, GPIODir.gdOutput, GPIOPull.gpOff)
  gpio.setup(EpdPin.epCs.int, GPIODir.gdOutput, GPIOPull.gpOff)

  spiDev.setMaxSpeedHz(2000000)
  spiDev.setMode(0b00)

  var epd2in7b = Epd2in7b(
    gpio: gpio,
    spiDev: spiDev
  )

  epd2in7b.setup()
  return epd2in7b
