#include "mainwindow.h"

#include <QApplication>
#include <QFile>
#include <QFontDatabase>
#include <QXmlStreamReader>
#include <QTextCodec>

int main(int argc, char* argv[]) {
#ifdef WIN32
  qputenv("QT_QPA_PLATFORM_PLUGIN_PATH", "C:\\");
#endif
  QApplication a(argc, argv);
  QTextCodec::setCodecForLocale(QTextCodec::codecForName("UTF-8"));
  int fontId =
    QFontDatabase::addApplicationFont(":/resources/SourceHanSansCN-Medium.otf");
  if (fontId != -1) {
    QStringList fontFamilies = QFontDatabase::applicationFontFamilies(fontId);
    if (!fontFamilies.empty())
      QApplication::setFont(QFont(fontFamilies.at(0)));
  }
  QFile qssFile(":/resources/theme.qss");
  if (qssFile.open(QFile::ReadOnly)) {
    QString styleSheet = QLatin1String(qssFile.readAll());
    a.setStyleSheet(styleSheet);
    qssFile.close();
  }
  QFont defaultFont = a.font();
  defaultFont.setPointSize(14);
  a.setFont(defaultFont);
  MainWindow w;
  w.show();
  return a.exec();
}
