#include "mainwindow.h"

#include <QApplication>
#include <QFile>
#include <QFontDatabase>
#include <QXmlStreamReader>

int
main(int argc, char* argv[]) {
  QApplication a(argc, argv);
  int fontId =
    QFontDatabase::addApplicationFont("://SourceHanSansCN-Medium.otf");
  if (fontId != -1) {
    QStringList fontFamilies = QFontDatabase::applicationFontFamilies(fontId);
    if (!fontFamilies.empty())
      QApplication::setFont(QFont(fontFamilies.at(0)));
  }
  QFile qssFile("://theme.qss");
  if (qssFile.open(QFile::ReadOnly)) {
    QString styleSheet = QLatin1String(qssFile.readAll());
    a.setStyleSheet(styleSheet);
    qssFile.close();
  }
  QFont defaultFont = a.font();
  defaultFont.setPointSize(14);
  a.setFont(defaultFont);
  MainWindow w;
  Q_INIT_RESOURCE(resources);
  w.show();
  return a.exec();
}
