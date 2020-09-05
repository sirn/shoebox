import os

import shoebox/gpio
import shoebox/spidev


const
  BtnPin1 = 5
  BtnPin2 = 6
  BtnPin3 = 13
  BtnPin4 = 19

const
  RstPin = 17
  DcPin = 25
  CsPin = 8
  BusyPin = 24


proc main() =
  var gpio = newGPIO()
  defer: gpio.close()

  gpio.setup(BtnPin1, GPIODir.input, GPIOPull.up)
  gpio.setup(BtnPin2, GPIODir.input, GPIOPull.up)
  gpio.setup(BtnPin3, GPIODir.input, GPIOPull.up)
  gpio.setup(BtnPin4, GPIODir.input, GPIOPull.up)

  gpio.setup(BusyPin, GPIODir.input, GPIOPull.off)
  gpio.setup(RstPin, GPIODir.output, GPIOPull.off)
  gpio.setup(DcPin, GPIODir.output, GPIOPull.off)
  gpio.setup(CsPin, GPIODir.output, GPIOPull.off)

  gpio.write(RstPin, GPIOValue.low)
  sleep(200)
  gpio.write(RstPin, GPIOValue.high)
  sleep(200)

  while true:
    echo "btn1:", gpio.read(BtnPin1),
     " btn2:", gpio.read(BtnPin2),
     " btn3:", gpio.read(BtnPin3),
     " btn4:", gpio.read(BtnPin4)

    sleep(100)


when isMainModule:
  main()
