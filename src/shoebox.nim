import os
import shoebox/gpio


const
  BTN1_PIN = 5
  BTN2_PIN = 6
  BTN3_PIN = 13
  BTN4_PIN = 19

const
  RST_PIN = 17
  DC_PIN = 25
  CS_PIN = 8
  BUSY_PIN = 24


proc main() =
  if setup() != SETUP_OK:
    echo "uhh? not root?"
    quit(1)

  defer:
    cleanup()

  setup_gpio(BTN1_PIN, DIR_IN, PUD_UP)
  setup_gpio(BTN2_PIN, DIR_IN, PUD_UP)
  setup_gpio(BTN3_PIN, DIR_IN, PUD_UP)
  setup_gpio(BTN4_PIN, DIR_IN, PUD_UP)

  setup_gpio(BUSY_PIN, DIR_IN, PUD_OFF)
  setup_gpio(RST_PIN, DIR_OUT, PUD_OFF)
  setup_gpio(DC_PIN, DIR_OUT, PUD_OFF)
  setup_gpio(CS_PIN, DIR_OUT, PUD_OFF)

  output_gpio(RST_PIN, LOW)
  sleep(200)
  output_gpio(RST_PIN, HIGH)
  sleep(200)

  while true:
    echo "btn1:", input_gpio(BTN1_PIN),
     " btn2:", input_gpio(BTN2_PIN),
     " btn3:", input_gpio(BTN3_PIN),
     " btn4:", input_gpio(BTN4_PIN)

    sleep(100)


when isMainModule:
  main()
