import shoebox/gpio
import shoebox/spidev
import shoebox/epd2in7b


proc main() =
  var gpio = newGPIO()
  var spiDev = newSPIDev(0, 0)

  defer:
    gpio.close()
    spiDev.close()

  discard newEpd2in7b(gpio, spiDev)


when isMainModule:
  main()
