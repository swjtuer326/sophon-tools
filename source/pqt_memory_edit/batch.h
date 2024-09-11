#ifndef BATCH_H
#define BATCH_H

#include <QDialog>
#include <QIntValidator>
#include <QRegExpValidator>
#include <QAbstractItemDelegate>
#include <QStandardItemModel>
#include <QStyledItemDelegate>
#include <QRegularExpression>
#include <QRegularExpressionValidator>
#include <QTableView>
#include <QTableWidget>
#include <QLineEdit>
#include <QSpinBox>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QDebug>
#include <QFileDialog>
#include <QMessageBox>
#include <QDir>
#include <QComboBox>
#include <QCheckBox>
#include <QFontMetrics>

#include "memoryedit.h"

namespace Ui {
class Batch;
}

class Batch : public QDialog {
  Q_OBJECT

 public:
  typedef struct {
    QString ip;
    quint64 port;
    QString user;
    QString passwd;
  } remoteInfStruct;

  explicit Batch(MemoryEdit::memInfoStruct& inMemInfo, QDir inLocalDir,
    remoteInfStruct* pRemoteInfStruct = nullptr, QWidget* parent = nullptr);
  ~Batch();
  void enableEdit(bool enable);
 public slots:
  void flashInfo(MemoryEdit::memInfoStruct* max,
    MemoryEdit::memInfoStruct* now);
  void flashStatus(QString status, quint64 id = 0);
  void comReturn(bool ok, quint64 id = 0);
  void WarningMessage(QString message, quint64 id = 0);
  void returnComLog(QString message, quint64 id = 0);
  void flashProgress(double progress, quint64 id = 0);

 private slots:
  void on_pushButton_5_clicked();

  void on_pushButton_6_clicked();

  void on_pushButton_2_clicked();

  void on_pushButton_clicked();

  void on_pushButton_3_clicked();

  void on_pushButton_4_clicked();

  void on_pushButton_7_clicked();

  void on_pushButton_8_clicked();

 private:
  Ui::Batch* ui;
  void readTableDataFromJson(QTableWidget* tableWidget,
    const QString& filePath);
  void writeTableDataToJson(const QTableWidget* tableWidget,
    const QString& filePath);
  void flashTableWidget(const QTableWidget* tableWidget);
  remoteInfStruct defaultRemoteInfStruct = {"127.0.0.1", 22, "linaro", "linaro"};
  quint64 remoteNum = 0;
  quint64 closeNum = 0;
  quint64 startNum = 0;
  QColor runningColor = QColor(255, 255, 153);
  QColor sucessColor = QColor(173, 255, 173);
  QColor errorColor = QColor(255, 173, 173);
  QColor noneColor = QColor(255, 255, 255);
  MemoryEdit::memInfoStruct memInfo;
  QDir localDir;
  void changeColorTableRow(QTableWidget* tableWidget, quint64 row, QColor color);
  void startBatch();
};

#endif // BATCH_H
