import shoebox/gpio
import shoebox/spidev
import shoebox/epd2in7b

import stb_image/read as stbi


proc loadImage(path: string, width: var int, height: var int): seq[uint8] =
  var
    channels: int
    data: seq[uint8]

  data = stbi.load(path, width, height, channels, stbi.Grey)

  var imageData: seq[uint8]
  imageData.setLen(len(data))
  for n in 0..(len(data) - 1):
    if data[n] != 255:
      imageData[n] = 1

  return imageData


proc main() =
  var gpio = newGPIO()
  var spiDev = newSPIDev(0, 0)
  var epd2in7b = newEpd2in7b(gpio, spiDev)

  defer:
    epd2in7b.powerOff()
    spiDev.close()
    gpio.close()

  var width: int
  var height: int
  var imageData: seq[uint8]
  var blackFb: seq[uint8]
  var redFb: seq[uint8]

  imageData = loadImage("bg_black.png", width, height)
  blackFb = epd2in7b.convertFb(imageData, EpdWidth, EpdHeight, EpdColor.ecBlack)
  redFb = epd2in7b.convertFb(@[], EpdWidth, EpdHeight, EpdColor.ecRed)
  epd2in7b.renderFb(blackFb, EpdColor.ecBlack)
  epd2in7b.renderFb(redFb, EpdColor.ecRed)
  epd2in7b.displayRefresh()

  imageData = loadImage("diff1.png", width, height)
  redFb = epd2in7b.convertFb(imageData, width, height, EpdColor.ecRed)
  epd2in7b.renderFbPartial(redFb, 80, 80, width, height, EpdColor.ecRed)
  epd2in7b.displayRefreshPartial(80, 80, width, height)


when isMainModule:
  main()
