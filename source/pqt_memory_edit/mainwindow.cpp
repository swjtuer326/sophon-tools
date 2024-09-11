#include "mainwindow.h"

#include <QDebug>
#include <QPalette>
#include <QPixmap>
#include <QResource>
#include <QString>

#include "./ui_mainwindow.h"

MainWindow::MainWindow(QWidget* parent)
  : QMainWindow(parent)
  , ui(new Ui::MainWindow) {
  ui->setupUi(this);
  ui->lineEdit_user->setValidator(&userPasswdValidator);
  ui->lineEdit_passwd->setValidator(&userPasswdValidator);
  lableno = new QLabel(this);
  lablep = new QLabel(this);
  ui->label->setOpenExternalLinks(true);
  localDir = QDir::current();
#ifdef WIN32
  WSADATA wsadata;
  int err;
  err = WSAStartup(MAKEWORD(2, 0), &wsadata);
  if (err != 0) {
    qWarning("WSAStartup failed with error: %d\n", err);
    exit(-1);
  }
#endif
  if (!libssh2_version(LIBSSH2_VERSION_NUM)) {
    qWarning("Runtime libssh2 version too old!");
    exit(-1);
  }
  qDebug("libssh2 version: %s", libssh2_version(0));
  rc = libssh2_init(0);
  if (rc != 0) {
    qWarning("libssh2 initialization failed (%d)\n", rc);
    exit(-1);
  }
  qDebug("libss2 init success!");
  ui->statusBar->addPermanentWidget(lableno, 1);
  ui->statusBar->addPermanentWidget(lablep, 0);
  ui->statusBar->setSizeGripEnabled(true);
  flashStatus("远程内存布局修改工具");
  ui->lineEdit_dir->setText(localDir.path());
  lablep->setText("      ");
  QPixmap pixmap("://sophgo-logo-new2.png");
  ui->label_16->setPixmap(pixmap);
  ui->label_16->setScaledContents(true);
  QString tS = ui->label->text();
  tS.replace("VX.X.X", MY_PROJECT_VERSION);
  ui->label->setText(tS);
  saveFilePath = localDir.path() + QDir::separator() + ".qtMemEditSaveConf";
  Batch::remoteInfStruct saveRemoteConf = readStructFromConfig(saveFilePath);
  if (saveRemoteConf.ip != "" && saveRemoteConf.port != 0
    && saveRemoteConf.user != "" && saveRemoteConf.passwd != "") {
    ui->lineEdit_ip->setText(saveRemoteConf.ip);
    ui->lineEdit_user->setText(saveRemoteConf.user);
    ui->lineEdit_passwd->setText(saveRemoteConf.passwd);
    ui->spinBox_port->setValue(saveRemoteConf.port);
  }
}

MainWindow::~MainWindow() {
  delete ui;
  libssh2_exit();
#ifdef WIN32
  WSACleanup();
#endif
}

void
MainWindow::flashInfo(MemoryEdit::memInfoStruct* max,
  MemoryEdit::memInfoStruct* now) {
  qDebug() << "flashInfo get info";
  if (max->vpu_mem_to_npuvpp_flag) {
    ui->spinBox_npu->setMaximum(max->npu_mem);
    ui->lineEditNpuMax->setText(
      QString("NPU可配置最大 %1 MiB").arg(max->npu_mem));
    ui->spinBox_vpp->setMaximum(max->vpp_mem);
    ui->lineEditVpuMax->setText(
      QString("VPP可配置最大 %1 MiB").arg(max->vpp_mem));
    ui->spinBox_vpu->setMaximum(0);
    ui->lineEditVppMax->setText(
      QString("NPU+VPP最大 %1 MiB").arg(max->vpu_mem));
    ui->spinBox_npu->setValue(now->npu_mem);
    ui->lineEditNpuNow->setText(QString("NPU当前 %1 MiB").arg(now->npu_mem));
    ui->spinBox_vpp->setValue(now->vpp_mem);
    ui->lineEditVpuNow->setText(QString("VPP当前 %1 MiB").arg(now->vpp_mem));
    ui->spinBox_vpu->setValue(0);
    ui->lineEditVppNow->setText(QString("NPU+VPP当前 %1 MiB").arg(
        now->npu_mem + now->vpp_mem));
    vpu_mem_to_npuvpp_value = max->vpu_mem;
    ui->spinBox_npu->disconnect();
    ui->spinBox_vpp->disconnect();
    connect(ui->spinBox_npu, QOverload<int>::of(&QSpinBox::valueChanged),
    this, [this](int i) {
      if (i + this->ui->spinBox_vpp->value() > this->vpu_mem_to_npuvpp_value)
        this->ui->spinBox_vpp->setValue(vpu_mem_to_npuvpp_value - i);
    });
    connect(ui->spinBox_vpp, QOverload<int>::of(&QSpinBox::valueChanged),
    this, [this](int i) {
      if (i + this->ui->spinBox_npu->value() > this->vpu_mem_to_npuvpp_value)
        this->ui->spinBox_npu->setValue(vpu_mem_to_npuvpp_value - i);
    });
  }
  else {
    ui->spinBox_npu->setMaximum(max->npu_mem);
    ui->lineEditNpuMax->setText(
      QString("NPU可配置最大 %1 MiB").arg(max->npu_mem));
    ui->spinBox_vpu->setMaximum(max->vpu_mem);
    ui->lineEditVpuMax->setText(
      QString("VPU可配置最大 %1 MiB").arg(max->vpu_mem));
    ui->spinBox_vpp->setMaximum(max->vpp_mem);
    ui->lineEditVppMax->setText(
      QString("VPP可配置最大 %1 MiB").arg(max->vpp_mem));
    ui->spinBox_npu->setValue(now->npu_mem);
    ui->lineEditNpuNow->setText(QString("NPU当前 %1 MiB").arg(now->npu_mem));
    ui->spinBox_vpu->setValue(now->vpu_mem);
    ui->lineEditVpuNow->setText(QString("VPU当前 %1 MiB").arg(now->vpu_mem));
    ui->spinBox_vpp->setValue(now->vpp_mem);
    ui->lineEditVppNow->setText(QString("VPP当前 %1 MiB").arg(now->vpp_mem));
    ui->spinBox_npu->disconnect();
    ui->spinBox_vpp->disconnect();
  }
}

void
MainWindow::flashStatus(QString status, quint64 id) {
  lableno->setText(status);
  lablep->setText("      ");
}

void
MainWindow::comReturn(bool ok, quint64 id) {
  enableEdit(true);
  if (ok == true) {
    writeStructToConfig(saveFilePath, {
      ui->lineEdit_ip->text(),
      (quint64)ui->spinBox_port->value(),
      ui->lineEdit_user->text(),
      ui->lineEdit_passwd->text()
    });
  }
}

void
MainWindow::WarningMessage(QString message, quint64 id) {
  QMessageBox::warning(this, "警告", message);
  if (!(message.contains("error", Qt::CaseInsensitive) ||
      message.contains("warning", Qt::CaseInsensitive)))
    flashStatus(message);
}

void
MainWindow::returnComLog(QString message, quint64 id) {
  ui->textEdit_sshinfo->append(message);
}

void
MainWindow::flashProgress(double progress, quint64 id) {
  lablep->setText(QString::number(progress * 100, 'd', 2) + "%");
}

void
MainWindow::enableEdit(bool enable) {
  ui->pushButton_2->setEnabled(enable);
  ui->pushButton_3->setEnabled(enable);
  ui->pushButton_4->setEnabled(enable);
  ui->pushButton_5->setEnabled(enable);
  ui->pushButton_6->setEnabled(enable);
  ui->spinBox_npu->setEnabled(enable);
  ui->spinBox_port->setEnabled(enable);
  ui->spinBox_vpp->setEnabled(enable);
  ui->spinBox_vpu->setEnabled(enable);
  ui->lineEdit_ip->setEnabled(enable);
  ui->lineEdit_passwd->setEnabled(enable);
  ui->lineEdit_user->setEnabled(enable);
}

bool
MainWindow::ipv4Check(QString ip) {
  static QRegularExpression regex(
    "^((\\d{1,2}|1\\d{2}|2[0-4]\\d|25[0-5])\\.){3}(\\d{"
    "1,2}|1\\d{2}|2[0-4]\\d|25[0-5])$");
  QRegularExpressionMatch match = regex.match(ip);
  return match.hasMatch();
}

void
MainWindow::on_pushButton_2_clicked() {
  if (!ipv4Check(ui->lineEdit_ip->text())) {
    QMessageBox::warning(this, "警告", "ip地址格式有误");
    return;
  }
  enableEdit(false);
  pMemoryEdit = new MemoryEdit(this);
  pMemoryEdit->setLoginInfo(ui->lineEdit_ip->text(),
    ui->spinBox_port->value(),
    ui->lineEdit_user->text(),
    ui->lineEdit_passwd->text(),
    localDir,
    0);
  pMemoryEdit->start();
}

void
MainWindow::on_pushButton_3_clicked() {
  if (!ipv4Check(ui->lineEdit_ip->text())) {
    QMessageBox::warning(this, "警告", "ip地址格式有误");
    return;
  }
  enableEdit(false);
  pMemoryEdit = new MemoryEdit(this);
  pMemoryEdit->memSet.npu_mem = ui->spinBox_npu->value();
  pMemoryEdit->memSet.vpu_mem = ui->spinBox_vpu->value();
  pMemoryEdit->memSet.vpp_mem = ui->spinBox_vpp->value();
  pMemoryEdit->setLoginInfo(ui->lineEdit_ip->text(),
    ui->spinBox_port->value(),
    ui->lineEdit_user->text(),
    ui->lineEdit_passwd->text(),
    localDir,
    1);
  pMemoryEdit->start();
}

void
MainWindow::on_pushButton_4_clicked() {
  QMessageBox::information(
    this,
    "帮助",
    "开发框架与库：\n基于QT 5.14和libssh2开发\n\n"
    "使用说明：\n1.请确定主机可以ssh到设备上\n2."
    "配置设备IP、端口和认证信息\n3."
    "点击获取信息按钮，验证链接是否成功并获取可以配置的最大内存与当前的配置信"
    "息"
    "\n4.输入您需要的三个内存区域的大小（单位MiB且不需要请输入0）\n5."
    "点击配置按钮，等待配置完成\n\n如果需要导出修改后的emmcboot."
    "itb，请保存远程内存修改的过程文件(memory_edit_p_前缀的文件)"
    "，将其解压后便可拷贝emmcboot."
    "itb到同类型同版本的微服务器的/boot目录下从而让其也使能修改后的内存布局");
}

void
MainWindow::on_pushButton_5_clicked() {
  QString selectedDirectory = QFileDialog::getExistingDirectory(
      nullptr, "Select Directory", "", QFileDialog::ShowDirsOnly);
  if (!selectedDirectory.isEmpty())
    localDir.setPath(selectedDirectory);
  else {
  }
  ui->lineEdit_dir->setText(localDir.path());
}

void MainWindow::on_pushButton_6_clicked() {
  Batch::remoteInfStruct inf = {ui->lineEdit_ip->text(),
                           (quint64)ui->spinBox_port->value(),
                           ui->lineEdit_user->text(),
                           ui->lineEdit_passwd->text()
                         };
  MemoryEdit::memInfoStruct memSet;
  memSet.npu_mem = ui->spinBox_npu->value();
  memSet.vpu_mem = ui->spinBox_vpu->value();
  memSet.vpp_mem = ui->spinBox_vpp->value();
  pBatch = new Batch(memSet, localDir, &inf, this);
  pBatch->setWindowModality(Qt::WindowModal);
  pBatch->exec();
  delete pBatch;
}

void MainWindow::writeStructToConfig(const QString& fileName,
  const Batch::remoteInfStruct& data) {
  QFile file(fileName);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
    qWarning() << "Failed to open file for writing:" << fileName;
    return;
  }
  QTextStream out(&file);
  out << data.ip << "\n";
  out << data.port << "\n";
  out << data.user << "\n";
  out << data.passwd << "\n";
  file.close();
}

Batch::remoteInfStruct MainWindow::readStructFromConfig(
  const QString& fileName) {
  Batch::remoteInfStruct data = {"", 0, "", ""};
  QFile file(fileName);
  if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    qWarning() << "Failed to open file for reading:" << fileName;
    return data;
  }
  QTextStream in(&file);
  in >> data.ip;
  in >> data.port;
  in >> data.user;
  in >> data.passwd;
  file.close();
  return data;
}

