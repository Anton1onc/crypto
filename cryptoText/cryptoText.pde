import controlP5.*;
ControlP5 cp5;
Textarea debugArea;
String cryptPath="", refPath="", textPath="";
PImage imageCrypt, imageRef;
int imgWidth;

void setup() {
  size(500, 250);

  // GUI
  cp5 = new ControlP5(this);
  cp5.addButton("load_ref").setCaptionLabel("Загрузить картинку")
  .setPosition(10, 10)
  .setSize(230, 35)
  .setColorBackground(color(20))
  .setFont(createFont("arial", 12))
  ;
  
  cp5.addButton("load_crypt_text")
  .setCaptionLabel("Загрузить текст")
  .setPosition(10, 50)
  .setSize(230, 35)
  .setColorBackground(color(20))
  .setFont(createFont("arial", 12))
  ;
  
  cp5.addButton("load_crypt")
  .setCaptionLabel("Загрузить шифр. картинку")
  .setPosition(10, 90)
  .setSize(230, 35)
  .setColorBackground(color(20))
  .setFont(createFont("arial", 12))
  ;
  
  cp5.addTextfield("key")
    .setPosition(10, 130)
    .setSize(230, 30)
    .setFont(createFont("arial", 15))
    .setAutoClear(false)
    .setCaptionLabel("")
    .setText("Ключ")
    .setColor(color(255))
    .setColorBackground(color(20))
    ;
    
 cp5.addButton("decrypt")
  .setCaptionLabel("Расшифровать")
  .setPosition(10, 165)
  .setSize(230, 35)
  .setFont(createFont("arial", 12))
  .setColorBackground(color(20))
  ;
  
  cp5.addButton("encrypt")
  .setCaptionLabel("Зашифровать")
  .setPosition(10, 205)
  .setSize(230, 35)
  .setFont(createFont("arial", 12))
  .setColorBackground(color(20))
  ;  

  debugArea = cp5.addTextarea("decryptText")
    .setPosition(250, 10)
    .setSize(240, 230)
    .setFont(createFont("arial", 14))
    .setLineHeight(14)
    .setColor(color(255))
    .setColorBackground(color(20))
    .setColorForeground(color(180));
  ;
}

void draw() {
}

// получаем сид из ключа шифрования
int getSeed() {  
  String thisKey = cp5.get(Textfield.class, "key").getText();
  int keySeed = 1;
  for (int i = 0; i < thisKey.length()-1; i++) 
    keySeed *= int(thisKey.charAt(i) * (thisKey.charAt(i)-thisKey.charAt(i+1)));  // перемножением с разностью
  return keySeed;
}

// кнопка шифровки
void encrypt() {
  if (refPath.length() != 0 && textPath.length() != 0) {
    // загружаем картинку и считаем её размер
    imageCrypt = loadImage(refPath);
    imageCrypt.loadPixels();
    int imgSize = imageCrypt.width * imageCrypt.height;

    // загружаем текст и считаем его размер
    String[] lines = loadStrings(textPath);    
    int textSize = 0;
    for (int i = 0; i < lines.length; i++) textSize += (lines[i].length() + 1);  // +1 на перенос    

    // ошибки
    if (textSize == 0) {
      debugArea.setText("Файл с текстом пуст!");
      return;
    }
    if (textSize >= imgSize) {
      debugArea.setText("Картинка слишком мала!");
      return;
    }

    // добавляем ноль (ноль как число!) в самый конец текста
    lines[lines.length-1] += '\0';
    textSize += 1;

    randomSeed(getSeed());

    // переменные
    int[] pixs = new int[textSize];  // запоминает предыдущие занятые пиксели    
    int counter = 0;

    // цикл шифрования
    for (int i = 0; i < lines.length; i++) {         // пробегаем по строкам
      for (int j = 0; j < lines[i].length() + 1; j++) {  // и каждому символу в них +1

        // поиск свободного пикселя
        int thisPix;
        while (true) {
          thisPix = (int)random(0, imgSize);         // выбираем случайный
          boolean check = true;                      // флаг проверки
          for (int k = 0; k < counter; k++) {        // пробегаем по предыдущим выбранным пикселям
            if (thisPix == pixs[k]) check = false;   // если пиксель уже занят, флаг опустить
          }
          if (check) {                               // пиксель свободен
            pixs[counter] = thisPix;                 // запоминаем в буфер
            counter++;                               // ++
            break;                                   // покидаем цикл
          }
        }        
        
        int thisChar;
        if (j == lines[i].length()) thisChar = int('\n');  // последний - перенос строки
        else thisChar = lines[i].charAt(j);       // читаем текущий символ
        
        if (thisChar > 1000) thisChar -= 890;    // костыль для русских букоф        

        int thisColor = imageCrypt.pixels[thisPix];  // читаем пиксель

        // упаковка в RGB 323
        int newColor = (thisColor & 0xF80000);   // 11111000 00000000 00000000
        newColor |= (thisChar & 0xE0) << 11;     // 00000111 00000000 00000000
        newColor |= (thisColor & (0x3F << 10));  // 00000000 11111100 00000000
        newColor |= (thisChar & 0x18) << 5;      // 00000000 00000011 00000000
        newColor |= (thisColor & (0x1F << 3));   // 00000000 00000000 11111000
        newColor |= (thisChar & 0x7);            // 00000000 00000000 00000111

        imageCrypt.pixels[thisPix] = newColor;   // запихиваем обратно в картинку
      }
    }
    imageCrypt.updatePixels();                   // обновляем изображение
    imageCrypt.save("crypt_image.bmp");          // сохраняем
    debugArea.setText("Готово");
  } else debugArea.setText("Вы не выбрали картинку!");
}

// кнопка дешифровки
void decrypt() {
  if (cryptPath.length() != 0) {
    // загружаем картинку и считаем её размер
    imageCrypt = loadImage(cryptPath);
    imageCrypt.loadPixels();
    int imgSize = imageCrypt.width * imageCrypt.height;

    randomSeed(getSeed());

    int[] pixs = new int[imgSize];  // буфер занятых пикселей
    String decryptText = "";        // буфер текста
    int counter = 0;

    // цикл дешифровки
    while (true) {

      // поиск свободного пикселя, такой же как выше
      int thisPix;
      while (true) {    
        thisPix = (int)random(0, imgSize);
        boolean check = true;
        for (int k = 0; k < counter; k++) {
          if (thisPix == pixs[k]) check = false;
        }
        if (check) {
          pixs[counter] = thisPix;
          counter++;          
          break;
        }
      }

      // читаем пиксель
      int thisColor = imageCrypt.pixels[thisPix];

      // распаковка из RGB 323 обратно в байт
      int thisChar = 0;
      thisChar |= (thisColor & 0x70000) >> 11;  // 00000111 00000000 00000000 -> 00000000 00000000 11100000
      thisChar |= (thisColor & 0x300) >> 5;     // 00000000 00000011 00000000 -> 00000000 00000000 00011000
      thisChar |= (thisColor & 0x7);            // 00000000 00000000 00000111

      if (thisChar > 130) thisChar += 890;      // костыль для русских букоф
      if (thisChar == 0) break;                 // конец текста (этот ноль мы сами добавили в конец). Выходим
      decryptText += char(thisChar);            // пишем в буфер
    }
    debugArea.setText(decryptText);            // выводим в гуи

    // и сохраняем в txt
    String[] lines = new String[1];
    lines[0] = decryptText;
    saveStrings("decrypt_text.txt", lines);
  } else debugArea.setText("Вы не выбрали картинку!");
}

// прочие кнопки
void load_ref() {
  selectInput("", "selectRef");
}

void selectRef(File selection) {
  if (selection != null) {
    refPath = selection.getAbsolutePath();
    debugArea.setText(refPath);
  } else debugArea.setText("Вы не выбрали картинку!");
}

void load_crypt() {
  selectInput("", "selectCrypt");
}

void selectCrypt(File selection) {
  if (selection != null) {
    cryptPath = selection.getAbsolutePath();
    debugArea.setText(cryptPath);
  } else debugArea.setText("Вы не выбрали картинку для разшифровки!");
}

void load_crypt_text() {
  selectInput("", "selectCryptText");
}

void selectCryptText(File selection) {
  if (selection != null) {
    textPath = selection.getAbsolutePath();
    debugArea.setText(textPath);
  } else debugArea.setText("Вы не выбрали файл с текстом!");
}
