import os

import gpio
import spidev


type
  Epd2in7b* = object
    gpio*: GPIO
    spiDev*: SpiDev

  Pin* = enum
    btn1 = 5,
    btn2 = 6,
    cs = 8,
    btn3 = 13,
    rst = 17,
    btn4 = 19,
    busy = 24,
    dc = 25


const
  Epd2in7bWidth* = 176
  Epd2in7bHeight* = 264


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

  LutVcomDc = [
    0x00, 0x00,
    0x00, 0x1A, 0x1A, 0x00, 0x00, 0x01,
    0x00, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x00, 0x0E, 0x01, 0x0E, 0x01, 0x10,
    0x00, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x00, 0x04, 0x10, 0x00, 0x00, 0x05,
    0x00, 0x03, 0x0E, 0x00, 0x00, 0x0A,
    0x00, 0x23, 0x00, 0x00, 0x00, 0x01
  ]

  # R21H
  LutWw = [
    0x90, 0x1A, 0x1A, 0x00, 0x00, 0x01,
    0x40, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x84, 0x0E, 0x01, 0x0E, 0x01, 0x10,
    0x80, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x00, 0x04, 0x10, 0x00, 0x00, 0x05,
    0x00, 0x03, 0x0E, 0x00, 0x00, 0x0A,
    0x00, 0x23, 0x00, 0x00, 0x00, 0x01
  ]

  # R22H    r
  LutBw = [
    0xA0, 0x1A, 0x1A, 0x00, 0x00, 0x01,
    0x00, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x84, 0x0E, 0x01, 0x0E, 0x01, 0x10,
    0x90, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0xB0, 0x04, 0x10, 0x00, 0x00, 0x05,
    0xB0, 0x03, 0x0E, 0x00, 0x00, 0x0A,
    0xC0, 0x23, 0x00, 0x00, 0x00, 0x01
  ]

  # R23H    w
  LutBb = [
    0x90, 0x1A, 0x1A, 0x00, 0x00, 0x01,
    0x40, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x84, 0x0E, 0x01, 0x0E, 0x01, 0x10,
    0x80, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x00, 0x04, 0x10, 0x00, 0x00, 0x05,
    0x00, 0x03, 0x0E, 0x00, 0x00, 0x0A,
    0x00, 0x23, 0x00, 0x00, 0x00, 0x01
  ]

  # R24H    b
  LutWb = [
    0x90, 0x1A, 0x1A, 0x00, 0x00, 0x01,
    0x20, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x84, 0x0E, 0x01, 0x0E, 0x01, 0x10,
    0x10, 0x0A, 0x0A, 0x00, 0x00, 0x08,
    0x00, 0x04, 0x10, 0x00, 0x00, 0x05,
    0x00, 0x03, 0x0E, 0x00, 0x00, 0x0A,
    0x00, 0x23, 0x00, 0x00, 0x00, 0x01
  ]


proc newEpd2in7b*(gpio: GPIO, spiDev: SpiDev): Epd2in7b =
  gpio.setup(Pin.btn1.int, GPIODir.input, GPIOPull.up)
  gpio.setup(Pin.btn2.int, GPIODir.input, GPIOPull.up)
  gpio.setup(Pin.btn3.int, GPIODir.input, GPIOPull.up)
  gpio.setup(Pin.btn4.int, GPIODir.input, GPIOPull.up)

  gpio.setup(Pin.busy.int, GPIODir.input, GPIOPull.off)
  gpio.setup(Pin.rst.int, GPIODir.output, GPIOPull.off)
  gpio.setup(Pin.dc.int, GPIODir.output, GPIOPull.off)
  gpio.setup(Pin.cs.int, GPIODir.output, GPIOPull.off)

  spiDev.setMaxSpeedHz(2000000)
  spiDev.setMode(0b00)

  return Epd2in7b(
    gpio: gpio,
    spiDev: spiDev
  )


proc sendCommand(a: Epd2in7b, command: int) =
  a.gpio.write(Pin.dc.int, GPIOValue.low)
  a.spiDev.writeByte(byte(command))


proc sendData(a: Epd2in7b, command: int) =
  a.gpio.write(Pin.dc.int, GPIOValue.high)
  a.spiDev.writeByte(byte(command))


template sendCommandWithData(a: Epd2in7b, command: int, data: varargs[int]) =
  a.sendCommand(command)
  for d in data:
    a.sendData(d)


proc wait*(a: Epd2in7b) =
  while a.gpio.read(Pin.busy.int) == GPIOValue.low:
    sleep(100)


proc reset*(a: Epd2in7b) =
  a.gpio.write(Pin.rst.int, GPIOValue.low)
  sleep(200)
  a.gpio.write(Pin.rst.int, GPIOValue.high)
  sleep(200)


proc powerOn*(a: Epd2in7b) =
  a.sendCommand(PowerOn)


proc powerOff*(a: Epd2in7b) =
  a.sendCommand(PowerOff)


proc deepSleep*(a: Epd2in7b) =
  a.sendCommand(DeepSleep)
  a.sendData(0xa5)


proc init*(a: Epd2in7b) =
  a.reset()

  # Power on
  a.sendCommand(PowerOn)
  a.wait()

  sendCommandWithData(a, PanelSetting, 0xaf)
  sendCommandWithData(a, PllControl, 0x3a)
  sendCommandWithData(a, PowerSetting, 0x03, 0x00, 0x2b, 0x2b, 0x09)
  sendCommandWithData(a, BoosterSoftStart, 0x07, 0x07, 0x17)

  # Power optimization
  sendCommandWithData(a, 0xf8, 0x60, 0xa5)
  sendCommandWithData(a, 0xf8, 0x89, 0xa5)
  sendCommandWithData(a, 0xf8, 0x90, 0x00)
  sendCommandWithData(a, 0xf8, 0x93, 0x2a)
  sendCommandWithData(a, 0xf8, 0x73, 0x41)

  sendCommandWithData(a, VcmDcSettingRegister, 0x12)
  sendCommandWithData(a, VcomAndDataIntervalSetting, 0x87)
  sendCommandWithData(a, LutForVcom, LutVcomDc)
  sendCommandWithData(a, LutWhiteToWhite, LutWw)
  sendCommandWithData(a, LutBlackToWhite, LutBw)
  sendCommandWithData(a, LutWhiteToBlack, LutWb)
  sendCommandWithData(a, LutBlackToBlack, LutBb)
  sendCommandWithData(a, PartialDisplayRefresh, 0x00)

  # TODO: Remove me all the code below
  # Hard screen clear
  sendCommandWithData(
    a,
    TconResolution,
    Epd2in7bWidth shr 8,
    Epd2in7bWidth and 0xff,
    Epd2in7bHeight shr 8,
    Epd2in7bHeight and 0xff,
  )

  # Black channel
  a.sendCommand(DataStartTransmission1)
  sleep(2)
  for i in 0..int((Epd2in7bWidth * Epd2in7bHeight / 8)):
    a.sendData(0xff)
  sleep(2)

  # Red channel
  a.sendCommand(DataStartTransmission2)
  sleep(2)
  for i in 0..int((Epd2in7bWidth * Epd2in7bHeight / 8)):
    a.sendData(0x00)
  sleep(2)

  a.sendCommand(DisplayRefresh)
  a.wait()
  a.powerOff()
