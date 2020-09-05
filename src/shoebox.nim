import shoebox/gpio
import shoebox/spidev
import shoebox/epd2in7b


proc main() =
  var gpio = newGPIO()
  var spiDev = newSpiDev(0, 0)

  defer:
    gpio.close()
    spiDev.close()

  var epd2in7b = newEpd2in7b(gpio, spiDev)
  epd2in7b.init()


when isMainModule:
  main()
