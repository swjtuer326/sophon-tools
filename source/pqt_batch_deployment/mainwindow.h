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
#include <QDebug>
#include <QPalette>
#include <QPixmap>
#include <QResource>
#include <QStringList>
#include <QDialog>
#include <QIntValidator>
#include <QRegExpValidator>
#include <QAbstractItemDelegate>
#include <QStandardItemModel>
#include <QStyledItemDelegate>
#include <QTableView>
#include <QTableWidget>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QComboBox>
#include <QCheckBox>
#include <QFontMetrics>
#include <QMenu>
#include <QTimer>
#include <QDesktopServices>

#include "remotesshoperation.h"

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




 private slots:
  void on_pushButtonOpenRootPath_clicked();

  void on_pushButtonOpenJson_clicked();

  void on_comboBoxJson_currentTextChanged(const QString& arg1);

  void on_pushButtonSaveOneOperation_clicked();

  void on_pushButtonRun_clicked();

  void on_pushButtonUpfile_clicked();

  void on_pushButtonDownfile_clicked();

  void on_pushButtonSaveJson_clicked();

  void on_pushButtonOpenDown_clicked();

  void on_pushButtonHelp_clicked();

private:
  Ui::MainWindow* ui;
  QLabel* lableInfo;
  QLabel* lableEnd;
  QDir localDir;
  RemoteInfData* defaultRemoteInf;
  OperationInfData* defaultOperationInf;
  quint64 remoteNum = 0;
  quint64 closeNum = 0;
  quint64 startNum = 0;
  QColor runningColor = QColor(255, 255, 153);
  QColor sucessColor = QColor(173, 255, 173);
  QColor errorColor = QColor(255, 173, 173);
  QColor noneColor = QColor(255, 255, 255);
  QWidget* maskWidget;
  QLabel* maskLabelTop;
  QLabel* maskLabelLeft;
  QLabel* maskLabelRight;
  QLabel* maskLabelBottom;
  QPushButton *nextButton;
  qint64 helpCnt = 0;
  QLabel *helpInformation;
  qint64 cnt1 = 0;
  qint64 cnt2 = 0;
  qint64 cnt3 = 0;
  QList<QLayout*> list1;
  QList<QWidget*> list2;
  QList<QPushButton*> list3;
  QList<QString> helpInfoList;
  QList<qint64> posList;

  void maskHelpRegion(QList<qint64> a);

  bool maskWidgetisShow = 0;

  QList<qint64> getPos1(QWidget *a);
  QList<qint64> getPos2(QLayout *a);

  void resizeEvent(QResizeEvent *event);

  void flashStatusBarStatus(QString status, QString endStatus);
  void writeTableDataToJson(QTableWidget* remoteTable,
    QTableWidget* OperationTable, const QString& filePath);
  /* 初始化远程设备信息配置表格 */
  void initRemoteTable(QTableWidget* tableWidget);
  /* 初始化下拉菜单预设配置文件信息 */
  void initComboBoxJson(QComboBox* ComboBox, QDir RootPath);
  /* 克隆当前远程信息表格选中行 */
  void cloneRemoteTableSelectRow(QTableWidget* tableWidget);
  /* 删除当前选中行 */
  void removeTableWidgetSelectRow(QTableWidget* tableWidget);
  /* 初始化操作信息配置表格 */
  void initOperationTable(QTableWidget* tableWidget);
  /* 刷新操作信息配置表格选中 */
  void flashOperationTableCheck(const QTableWidget* tableWidget);
  /* 克隆当前操作信息表格选中行 */
  void cloneOperationTableSelectRow(QTableWidget* tableWidget);
  void readTableDataFromJson(QTableWidget* remoteTable,
    QTableWidget* OperationTable, const QString& filePath);
  /* 从表格中的私有数据刷新表格内容，仅限操作表格 */
  void flashOperationTableItems(QTableWidget* tableWidget);
  /* 从表格内容刷新表格私有数据，仅限远程设备信息表格 */
  void flashRemoteTableDatas(QTableWidget* tableWidget);
  void enableEdit(bool enable);
  /* 计算所有可计算文件的MD5值 */
  void md5SumAll(QTableWidget* tableWidget);
  /* 计算一个文件的MD5值 */
  QString calculateFileMD5(const QString& filePath);
  /* 使能操作表修改位置的修改功能 */
  void enableEditOperation(bool enable);
  /* 启动并行部署线程 */
  void startBatch(void);
  /* 改变一行颜色 */
  void changeColorTableRow(QTableWidget* tableWidget, quint64 row, QColor color);
 public slots:
  void flashStatus(QString status, quint64 id = 0);
  void comReturn(bool ok, quint64 id = 0);
  void WarningMessage(QString message, quint64 id = 0);
  void returnComLog(QString message, quint64 id = 0);
  void flashProgress(double progress, quint64 id = 0);
  void closeHelp();

};
#endif // MAINWINDOW_H
