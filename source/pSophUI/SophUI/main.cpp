#include "mainwindow.h"

#include <QApplication>
#include <QProcessEnvironment>
#include <QFont>
#include <QString>
#include <QFile>
#include <QFontDatabase>
#include <QScreen>
#include <QTranslator>

template <typename T>
static void __setFontRecursively(T *inObject, qint64 fontSize=15)
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString fontSizeStr = env.value("SOPHON_QT_FONT_SIZE");
    fontSize = fontSizeStr.toInt() > 0?fontSizeStr.toInt():fontSize;
    QFont font = inObject->font();
    font.setPointSize(fontSize);
    inObject->setFont(font);
    QObject *object = inObject;
    QList<T *> childObjects = object->findChildren<T *>();
    for (T *childObject : childObjects)
    {
        __setFontRecursively(childObject,fontSize);
    }
}

static QtMsgType infoLimit = QtWarningMsg;

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    QTranslator en;
    __setFontRecursively<QApplication>(&a);
    int fontId =
        QFontDatabase::addApplicationFont(":/font.file");
    if (fontId != -1) {
        QStringList fontFamilies = QFontDatabase::applicationFontFamilies(fontId);
        if (!fontFamilies.empty())
            QApplication::setFont(QFont(fontFamilies.at(0)));
    }
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString enEnable = env.value("SOPHON_QT_EN_ENABLE");
    if(enEnable == "1") {
        qDebug() << "enable english mode";
        bool flag = en.load(":/new/prefix1/en_US.qm");
        if(flag){
            qDebug() << "qm file load sucess";
            qApp->installTranslator(&en);
        }else
            qDebug() << "qm file load error";
    }
    QString fontSizeStr = env.value("SOPHON_QT_CMD_DEBUG");
    if(fontSizeStr == "1")
        infoLimit = QtDebugMsg;
    qSetMessagePattern("%{type}: %{message}");
    qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &, const QString &msg) {
        if (type >= infoLimit) {
            QTextStream(stdout) << msg << endl;
        }
    });

    MainWindow w;
    QString device_name = MainWindow::executeLinuxCmd("awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo").trimmed();
    qDebug() << device_name;
    if (device_name == "bm1688" || device_name == "cv186ah"){
        QScreen *primaryScreen = QGuiApplication::primaryScreen();
        int screenWidth = primaryScreen->size().width();; // 屏幕分辨率
        int screenHeight= primaryScreen->size().height(); // 屏幕分辨率宽度
        qDebug() << "Display size" << screenWidth << screenHeight;
        w.resize(screenWidth, screenHeight);
    }else{
        w.setFixedSize(1920, 1080);
    }
    w.fontId = fontId;
    w.app = &a;
    w.show();
    __setFontRecursively<QWidget>(&w);
    return a.exec();
}
