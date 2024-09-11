#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QIODevice>
#include <QLineEdit>
#include <QMainWindow>
#include <QMessageBox>
#include <QRegularExpression>
#include <QRegularExpressionValidator>
#include <QSpinBox>
#include <QStandardPaths>
#include <QString>
#include <QStringList>

#include "batch.h"

#include "memoryedit.h"
#include "version.h"

QT_BEGIN_NAMESPACE
namespace Ui {
class MainWindow;
}
QT_END_NAMESPACE

class MainWindow : public QMainWindow {
  Q_OBJECT

 public:
  MainWindow(QWidget* parent = nullptr);
  ~MainWindow();

 public slots:
  void flashInfo(MemoryEdit::memInfoStruct* max,
    MemoryEdit::memInfoStruct* now);
  void flashStatus(QString status, quint64 id = 0);
  void comReturn(bool ok, quint64 id = 0);
  void WarningMessage(QString message, quint64 id = 0);
  void returnComLog(QString message, quint64 id = 0);
  void flashProgress(double progress, quint64 id = 0);

 private slots:
  void on_pushButton_2_clicked();

  void on_pushButton_3_clicked();

  void on_pushButton_4_clicked();

  void on_pushButton_5_clicked();

  void on_pushButton_6_clicked();

 private:
  Ui::MainWindow* ui;

  void enableEdit(bool enable);
  bool ipv4Check(QString ip);

  QRegularExpressionValidator userPasswdValidator =
    QRegularExpressionValidator(QRegularExpression("^[ -~]*$"), this);

  QString re_buf, StatusTip;
  MemoryEdit* pMemoryEdit;
  quint64 vpu_mem_to_npuvpp_value = 0;
  QLabel* lableno;
  QLabel* lablep;
  QDir localDir;
  Batch* pBatch;
  int rc;
  void writeStructToConfig(const QString& fileName,
    const Batch::remoteInfStruct& data);
  Batch::remoteInfStruct readStructFromConfig(const QString& fileName);
  Batch::remoteInfStruct defaultRemoteConf;
  QString saveFilePath;
};
#endif // MAINWINDOW_H
