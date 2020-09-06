import shoebox/gpio
import shoebox/spidev
import shoebox/epd2in7b


proc main() =
  var gpio = newGPIO()
  var spiDev = newSPIDev(0, 0)
  var epd2in7b = newEpd2in7b(gpio, spiDev)

  defer:
    epd2in7b.powerOff()
    spiDev.close()
    gpio.close()

  var blackFb: EpdFb = epd2in7b.convertFb(@[
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 1'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 1'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8, 1'u8, 1'u8, 0'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8,
  ], 10, 10, EpdColor.ecBlack)

  var redFb: EpdFb = epd2in7b.convertFb(@[
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 1'u8, 1'u8,
    0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8,
  ], 12, 10, EpdColor.ecRed)

  epd2in7b.renderFb(blackFb, EpdColor.ecBlack)
  epd2in7b.renderFb(redFb, EpdColor.ecRed)
  epd2in7b.displayRefresh()
  epd2in7b.deepSleep()


when isMainModule:
  main()
