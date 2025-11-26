#include <Arduino.h>
#include <U8g2lib.h>

#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif

// Constructor para SSD1315 (compatible con SSD1306 en U8g2, I2C hardware con pines específicos para ESP32-C3)
U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* clock (SCL)=*/ 9, /* data (SDA)=*/ 8, /* reset=*/ U8X8_PIN_NONE);

void setup(void) {
  // Inicializa el display (automáticamente inicia Wire en pines 8/9)
  u8g2.begin();
}

void loop(void) {
  // Limpia el buffer
  u8g2.clearBuffer();
  
  // Configura fuente (pequeña y legible)
  u8g2.setFont(u8g2_font_ncenB08_tr);
  
  // Dibuja el texto en posición x=0, y=15 (ajusta si es necesario para centrar)
  u8g2.drawStr(0, 15, "hola prueba hola");
  
  // Envía el buffer al display
  u8g2.sendBuffer();
  
  // Espera 1 segundo
  delay(1000);
  
  // Opcional: Limpia la pantalla en el siguiente ciclo (parpadea)
  u8g2.clearBuffer();
  u8g2.sendBuffer();
  delay(500);
}