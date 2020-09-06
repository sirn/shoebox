import os
import algorithm

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
  EpdFb* = array[EpdMaxSize, uint8]


const
  PanelSetting = 0x00
  PowerSetting = 0x01
  PowerOff = 0x02
  PowerOffSequenceSetting = 0x03
  PowerOn = 0x04
  PowerOnMeasure = 0x05
  BoosterSoftStart = 0x06
  DeepSleep = 0x07
  DataStartTransmission1 = 0x10
  DataStop = 0x11
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
  TemperatureSensorCommand = 0x40
  TemperatureSensorCalibration = 0x41
  TemperatureSensorWrite = 0x42
  TemperatureSensorRead = 0x43
  VcomAndDataIntervalSetting = 0x50
  LowPowerDetection = 0x51
  TconSetting = 0x60
  TconResolution = 0x61
  SourceAndGateStartSetting = 0x62
  GetStatus = 0x71
  AutoMeasureVcom = 0x80
  VcomValue = 0x81
  VcmDcSettingRegister = 0x82
  ProgramMode = 0xA0
  ActiveProgram = 0xA1
  ReadOtpData = 0xA2
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
  while a.gpio.read(EpdPin.epBusy.int) == GPIOVal.gvLow:
    sleep(100)


proc powerOff*(a: Epd2in7b) =
  a.sendCmd(PowerOff)


proc deepSleep*(a: Epd2in7b) =
  a.sendCmd(DeepSleep)
  a.sendData(0xa5)


proc displayRefresh*(a: Epd2in7b) =
  a.sendCmd(DisplayRefresh)
  a.wait()


proc convertFb*(a: Epd2in7b, sSeq: openArray[uint8], sWidth: int, sHeight: int, color: EpdColor): EpdFb =
  ## Convert a sequence of uint8 into an EPD framebuffer.
  var fb {.noinit.}: EpdFb

  case color:
    of ecBlack:
      # Black fills 0xff (0) -> 0x00 (1)
      fb.fill(0xff)

      for y in 0..(sHeight - 1):
        for x in 0..(sWidth - 1):
          if sSeq[x + y * sWidth] != 0:
            var pos = int((x + y * EpdWidth) / 8)
            fb[pos] = fb[pos] and not uint8(0x80 shr (x mod 8))

    of ecRed:
      # Red fills 0x00 (0) -> 0xff (1) (yes this is annoying)
      fb.fill(0x00)

      for y in 0..(sHeight - 1):
        for x in 0..(sWidth - 1):
          if sSeq[x + y * sWidth] != 0:
            var pos = int((x + y * EpdWidth) / 8)
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
      sleep(2)
      for i in 0..(EpdMaxSize - 1):
        a.sendData(fb[i])
      sleep(2)
    of ecRed:
      a.sendCmd(DataStartTransmission2)
      sleep(2)
      for i in 0..(EpdMaxSize - 1):
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
