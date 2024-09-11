#include "mainwindow.h"
#include "./ui_mainwindow.h"
#include "tableDelegates.h"

Q_DECLARE_METATYPE(QSharedPointer<QString>)

MainWindow::MainWindow(QWidget* parent)
  : QMainWindow(parent)
  , ui(new Ui::MainWindow) {
  ui->setupUi(this);
  /* 配置状态栏 */
  lableInfo = new QLabel(this);
  lableEnd = new QLabel(this);
  ui->statusbar->addPermanentWidget(lableInfo, 1);
  ui->statusbar->addPermanentWidget(lableEnd, 0);
  ui->statusbar->setSizeGripEnabled(true);
  flashStatusBarStatus("批量部署工具", " ");
  lableEnd->setText("      ");
  /* 配置程序当前路径 */
  localDir = QDir::current();
  ui->lineEditRootPath->setText(localDir.path());
  /* 配置图标和版本号 */
  QPixmap pixmap(":/resources/sophgo-logo-new2.png");
  ui->labelImage->setPixmap(pixmap);
  ui->labelImage->setScaledContents(true);
  QString tS = ui->labelTitle->text();
  tS.replace("VX.X.X", MY_PROJECT_VERSION);
  ui->labelTitle->setText(tS);
  initRemoteTable(ui->tableWidgetRemote);
  initOperationTable(ui->tableWidgetOperation);
  initComboBoxJson(ui->comboBoxJson, QDir(":/resources/batchConf"));
  ui->lineEditCommandStr->setPlaceholderText(QString("需要执行的命令"));
  ui->lineEditCommandSuccessCheck->setPlaceholderText(
    QString("判断执行是否成功,为空不检查"));
  ui->lineEditCommandErrorCheck->setPlaceholderText(
    QString("判断执行是否失败,为空不检查"));
  ui->lineEditUpRemotePath->setPlaceholderText(
    QString("上传文件远程路径,仅支持英文"));
  ui->lineEditDownRemoteFile->setPlaceholderText(
    QString("下载文件远程路径,仅支持英文"));
  QRegExp regexPath("^[a-zA-Z0-9/\\\\.:_-]*$");
  QValidator* validatorPath = new QRegExpValidator(regexPath, this);
  ui->lineEditUpRemotePath->setValidator(validatorPath);
  ui->lineEditDownRemoteFile->setValidator(validatorPath);
  enableEditOperation(false);
  maskWidget = new QWidget(this);
  maskLabelTop = new QLabel(maskWidget);
  maskLabelLeft = new QLabel(maskWidget);
  maskLabelRight = new QLabel(maskWidget);
  maskLabelBottom = new QLabel(maskWidget);
  nextButton = new QPushButton("下一步", maskWidget);
  nextButton->setVisible(false);
  list1 = {ui->horizontalLayout_2, ui->horizontalLayout_3};
  list2 = {ui->tableWidgetRemote, ui->tableWidgetOperation, ui->tabWidgetOperation, ui->tabWidgetOperation, ui->textEditSshinfo};
  list3 = {ui->pushButtonOpenJson, ui->pushButtonSaveJson, ui->pushButtonRun};
  helpInformation = new QLabel(maskWidget);
  /* 配置WINDOWS下WSADATA */
#ifdef WIN32
  WSADATA wsadata;
  int err;
  err = WSAStartup(MAKEWORD(2, 0), &wsadata);
  if (err != 0) {
    qWarning("WSAStartup failed with error: %d\n", err);
    exit(-1);
  }
#endif
}

MainWindow::~MainWindow() {
  delete ui;
#ifdef WIN32
  WSACleanup();
#endif
}

void MainWindow::initComboBoxJson(QComboBox* ComboBox, QDir RootPath) {
  QFileInfoList fileList = RootPath.entryInfoList(QDir::Files |
      QDir::NoDotAndDotDot);
  ui->comboBoxJson->blockSignals(true);
  for (const QFileInfo& fileInfo : fileList) {
    QString fileName = fileInfo.fileName();
    ComboBox->addItem(fileName);
  }
  ui->comboBoxJson->blockSignals(false);
}

void MainWindow::initRemoteTable(QTableWidget* tableWidget) {
  defaultRemoteInf = new RemoteInfData("192.168.150.1", 22, "linaro",
    "linaro");
  tableWidget->setColumnCount(5);
  tableWidget->setHorizontalHeaderLabels({"IPv4地址", "SSH端口", "用户名", "密码", "执行状态"});
  tableWidget->setItemDelegateForColumn(0,
    new ipLineEditDelegate(this));
  tableWidget->setItemDelegateForColumn(1,
    new portSpinBoxDelegate(this));
  tableWidget->setItemDelegateForColumn(2,
    new infLineEditDelegate(this));
  tableWidget->setItemDelegateForColumn(3,
    new infLineEditDelegate(this));
  tableWidget->setRowCount(1);
  tableWidget->setSelectionBehavior(QAbstractItemView::SelectRows);
  tableWidget->horizontalHeader()->setStretchLastSection(true);
  tableWidget->setWordWrap(true);
  tableWidget->setItem(0, 0, new QTableWidgetItem(defaultRemoteInf->ip));
  tableWidget->setItem(0, 1,
    new QTableWidgetItem(QString::number(defaultRemoteInf->port)));
  tableWidget->setItem(0, 2,
    new QTableWidgetItem(defaultRemoteInf->user));
  tableWidget->setItem(0, 3,
    new QTableWidgetItem(defaultRemoteInf->passwd));
  tableWidget->setItem(0, 4, new QTableWidgetItem());
  QSharedPointer<RemoteInfData> shareRemoteInfData(defaultRemoteInf);
  QVariant variant = QVariant::fromValue(shareRemoteInfData);
  tableWidget->item(0, 0)->setData(Qt::UserRole, variant);
  QSharedPointer<QString> sshRunLog(new QString(""));
  QVariant variantRunLog = QVariant::fromValue(sshRunLog);
  tableWidget->item(0, 1)->setData(Qt::UserRole, variantRunLog);
  tableWidget->resizeColumnsToContents();
  tableWidget->horizontalHeader()->setSectionResizeMode(
    tableWidget->columnCount() - 1, QHeaderView::Stretch);
  connect(tableWidget,
  &QTableWidget::itemChanged, this, [this](QTableWidgetItem * item) {
    QTableWidget* tableWidget = item->tableWidget();
    tableWidget->resizeColumnsToContents();
    tableWidget->horizontalHeader()->setSectionResizeMode(
      tableWidget->columnCount() - 1, QHeaderView::Stretch);
    flashRemoteTableDatas(tableWidget);
  });
  tableWidget->setContextMenuPolicy(Qt::CustomContextMenu);
  QObject::connect(tableWidget,
    &QTableWidget::customContextMenuRequested,
  this, [this, tableWidget](const QPoint & pos) {
    QModelIndex index = tableWidget->indexAt(pos);
    if (index.isValid()) {
      QMenu contextMenu;
      QAction* cloneAction = contextMenu.addAction("克隆当前项");
      QAction* deleteAction = contextMenu.addAction("删除当前项");
      QAction* selectedAction = contextMenu.exec(QCursor::pos());
      if (selectedAction == deleteAction)
        this->removeTableWidgetSelectRow(tableWidget);
      else if (selectedAction == cloneAction)
        this->cloneRemoteTableSelectRow(tableWidget);
    }
  });
  QObject::connect(tableWidget, &QTableWidget::itemSelectionChanged, [this,
  tableWidget]() {
    int selectedRow = tableWidget->currentRow();
    QVariant customDataVariant = tableWidget->item(selectedRow,
        1)->data(Qt::UserRole);
    QSharedPointer<QString> sharePointer =
      customDataVariant.value <QSharedPointer<QString>>();
    QString* sshRunLog = sharePointer.data();
    ui->textEditSshinfo->setText(*sshRunLog);
    ui->label_11->setText(QString("设备%1").arg(selectedRow + 1));
  });
}

void MainWindow::initOperationTable(QTableWidget* tableWidget) {
  defaultOperationInf = new OperationInfData(
    "检查时间", OperationInfData::operationCommand, "date");
  tableWidget->setEditTriggers(QAbstractItemView::NoEditTriggers);
  tableWidget->setColumnCount(3);
  tableWidget->setRowCount(1);
  tableWidget->setHorizontalHeaderLabels({"操作名称", "操作类型", "内容信息"});
  tableWidget->setItem(0, 2, new QTableWidgetItem());
  tableWidget->item(0, 2)->setCheckState(Qt::Checked);
  tableWidget->setRowCount(1);
  tableWidget->setSelectionBehavior(QAbstractItemView::SelectRows);
  tableWidget->horizontalHeader()->setStretchLastSection(true);
  tableWidget->setWordWrap(true);
  tableWidget->setItem(0, 0, new QTableWidgetItem(defaultOperationInf->name));
  tableWidget->setItem(0, 1,
    new QTableWidgetItem(defaultOperationInf->operationTypeString()));
  tableWidget->setItem(0, 2,
    new QTableWidgetItem(defaultOperationInf->type ==
      OperationInfData::operationCommand ? defaultOperationInf->commandStr :
      defaultOperationInf->transferFileSourcePath));
  QSharedPointer<OperationInfData> shareRemoteInfData(defaultOperationInf);
  QVariant variant = QVariant::fromValue(shareRemoteInfData);
  tableWidget->item(0, 0)->setData(Qt::UserRole, variant);
  tableWidget->resizeColumnsToContents();
  connect(tableWidget,
  &QTableWidget::itemChanged, this, [this](QTableWidgetItem * item) {
    QTableWidget* tableWidget = item->tableWidget();
    tableWidget->resizeColumnsToContents();
    tableWidget->horizontalHeader()->setSectionResizeMode(
      tableWidget->columnCount() - 1, QHeaderView::Stretch);
  });
  tableWidget->setContextMenuPolicy(Qt::CustomContextMenu);
  QObject::connect(tableWidget,
    &QTableWidget::customContextMenuRequested,
  this, [this, tableWidget](const QPoint & pos) {
    QModelIndex index = tableWidget->indexAt(pos);
    if (index.isValid()) {
      QMenu contextMenu;
      QAction* cloneAction = contextMenu.addAction("克隆当前项");
      QAction* deleteAction = contextMenu.addAction("删除当前项");
      QAction* selectedAction = contextMenu.exec(QCursor::pos());
      if (selectedAction == deleteAction)
        this->removeTableWidgetSelectRow(tableWidget);
      else if (selectedAction == cloneAction)
        this->cloneOperationTableSelectRow(tableWidget);
    }
  });
  QObject::connect(tableWidget, &QTableWidget::itemSelectionChanged, [this,
  tableWidget]() {
    int selectedRow = tableWidget->currentRow();
    QVariant customDataVariant = tableWidget->item(selectedRow,
        0)->data(Qt::UserRole);
    QSharedPointer<OperationInfData> sharePointer =
      customDataVariant.value < QSharedPointer<OperationInfData>>();
    OperationInfData* operationData = sharePointer.data();
    QString infoStr;
    ui->tabWidgetOperation->setCurrentIndex(operationData->type);
    ui->lineEditOperationName->setText(operationData->name);
    ui->lineEditOperationStatus->setText(operationData->status == true ? "完整" :
      "不完整");
    switch (operationData->type) {
    case OperationInfData::operationCommand:
      infoStr = QString("当前选中项信息：名称:%1 操作类型:%2 命令:%3 命令成功检查:%4 命令失败检查:%5 当前信息完整度:%6").arg(
          operationData->name, operationData->operationTypeString(),
          operationData->commandStr, operationData->checkSuccessStr,
          operationData->checkErrorStr,
          operationData->status == true ? "完整" : "不完整");
      ui->lineEditCommandStr->setText(operationData->commandStr);
      ui->lineEditCommandSuccessCheck->setText(operationData->checkSuccessStr);
      ui->lineEditCommandErrorCheck->setText(operationData->checkErrorStr);
      break;
    case OperationInfData::operationUpFile:
      infoStr = QString("当前选中项信息：名称:%1 操作类型:%2 传输源文件:%3 传输目标:%4 文件检查方式:%5 当前信息完整度:%6").arg(
          operationData->name, operationData->operationTypeString(),
          operationData->transferFileSourcePath,
          operationData->transferFileDestinationPath,
          operationData->checkFileString(),
          operationData->status == true ? "完整" : "不完整");
      ui->lineEditUpfile->setText(operationData->transferFileSourcePath);
      ui->lineEditUpRemotePath->setText(operationData->transferFileDestinationPath);
      break;
    case OperationInfData::operationDownFile:
      infoStr = QString("当前选中项信息：名称:%1 操作类型:%2 传输源文件:%3 传输目标:%4 文件检查方式:%5 当前信息完整度:%6").arg(
          operationData->name, operationData->operationTypeString(),
          operationData->transferFileSourcePath,
          operationData->transferFileDestinationPath,
          operationData->checkFileString(),
          operationData->status == true ? "完整" : "不完整");
      ui->lineEditDownRemoteFile->setText(operationData->transferFileSourcePath);
      ui->lineEditDownDirPath->setText(operationData->transferFileDestinationPath);
      break;
    }
    enableEditOperation(true);
    qDebug() << infoStr;
  });
}

void MainWindow::flashStatusBarStatus(QString status, QString endStatus) {
  lableInfo->setText(status);
  lableEnd->setText(endStatus);
}

void MainWindow::on_pushButtonOpenRootPath_clicked() {
  QString selectedDirectory = QFileDialog::getExistingDirectory(
      nullptr, "Select Directory", "", QFileDialog::ShowDirsOnly);
  if (!selectedDirectory.isEmpty())
    localDir.setPath(selectedDirectory);
  else {
  }
  ui->lineEditRootPath->setText(localDir.path());
}

void MainWindow::writeTableDataToJson(QTableWidget* remoteTable,
  QTableWidget* OperationTable, const QString& filePath) {
  QJsonArray jsonArrayRemote, jsonArrayOperation;
  int columnCount = remoteTable->columnCount();
  for (int row = 0; row < remoteTable->rowCount(); ++row) {
    for (int col = 0; col < columnCount - 1; ++col) {
      if (remoteTable->item(row, col) == NULL) {
        QMessageBox::warning(this, "警告", "表格中有空行");
        return;
      }
    }
  }
  for (int row = 0; row < remoteTable->rowCount(); ++row) {
    QJsonObject jsonObject;
    jsonObject["IP"] = remoteTable->item(row, 0)->text();
    jsonObject["Port"] = remoteTable->item(row, 1)->text().toInt();
    jsonObject["Username"] = remoteTable->item(row, 2)->text();
    jsonObject["Password"] = remoteTable->item(row, 3)->text();
    jsonArrayRemote.append(jsonObject);
  }
  for (int row = 0; row < OperationTable->rowCount(); ++row) {
    QJsonObject jsonObject;
    QVariant customDataVariant = OperationTable->item(row,
        0)->data(Qt::UserRole);
    QSharedPointer<OperationInfData> sharePointer =
      customDataVariant.value <QSharedPointer<OperationInfData>>();
    OperationInfData* operationData = sharePointer.data();
    jsonObject["name"] = operationData->name;
    jsonObject["type"] = operationData->type;
    jsonObject["commandStr"] = operationData->commandStr;
    jsonObject["checkSuccessStr"] = operationData->checkSuccessStr;
    jsonObject["checkErrorStr"] = operationData->checkErrorStr;
    jsonObject["transferFileSourcePath"] = operationData->transferFileSourcePath;
    jsonObject["transferFileDestinationPath"] =
      operationData->transferFileDestinationPath;
    jsonObject["checkFile"] = operationData->checkFile;
    jsonArrayOperation.append(jsonObject);
  }
  QJsonObject finalObject;
  finalObject["remoteInf"] = jsonArrayRemote;
  finalObject["operationInf"] = jsonArrayOperation;
  QJsonDocument jsonDoc(finalObject);
  QFile file(filePath);
  if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
    file.write(jsonDoc.toJson());
    file.close();
    qDebug() << "Table data written to" << filePath;
  }
  else
    qWarning() << "Failed to open file for writing:" << file.errorString();
}

void MainWindow::readTableDataFromJson(QTableWidget* remoteTable,
  QTableWidget* operationTable, const QString& filePath) {
  QFile file(filePath);
  remoteTable->blockSignals(true);
  operationTable->blockSignals(true);
  if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
    QByteArray jsonData = file.readAll();
    file.close();
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData);
    if (jsonDoc.isObject()) {
      QJsonObject jsonObject = jsonDoc.object();
      if (jsonObject.contains("remoteInf") && jsonObject["remoteInf"].isArray()) {
        QJsonArray jsonArray = jsonObject["remoteInf"].toArray();
        remoteTable->clearContents();
        remoteTable->setRowCount(jsonArray.size());
        for (int row = 0; row < jsonArray.size(); ++row) {
          QJsonObject remoteInfo = jsonArray[row].toObject();
          remoteTable->setItem(row, 0, new QTableWidgetItem(remoteInfo["IP"].toString()));
          remoteTable->setItem(row, 1,
            new QTableWidgetItem(QString::number(remoteInfo["Port"].toInt())));
          remoteTable->setItem(row, 2,
            new QTableWidgetItem(remoteInfo["Username"].toString()));
          remoteTable->setItem(row, 3,
            new QTableWidgetItem(remoteInfo["Password"].toString()));
          remoteTable->setItem(row, 4, new QTableWidgetItem());
          RemoteInfData* remoteData = new RemoteInfData(remoteInfo["IP"].toString(),
            remoteInfo["Port"].toInt(),
            remoteInfo["Username"].toString(), remoteInfo["Password"].toString());
          QSharedPointer<RemoteInfData> shareRemoteInfData(remoteData);
          QVariant variant = QVariant::fromValue(shareRemoteInfData);
          remoteTable->item(row, 0)->setData(Qt::UserRole, variant);
          QSharedPointer<QString> sshRunLog(new QString(""));
          QVariant variantRunLog = QVariant::fromValue(sshRunLog);
          remoteTable->item(row, 1)->setData(Qt::UserRole, variantRunLog);
        }
        qDebug() << "Table data read from" << filePath;
      }
      else
        QMessageBox::warning(this, "警告", "Invalid JSON data in file");
      if (jsonObject.contains("operationInf")
        && jsonObject["operationInf"].isArray()) {
        QJsonArray jsonArray = jsonObject["operationInf"].toArray();
        operationTable->clearContents();
        operationTable->setRowCount(jsonArray.size());
        for (int row = 0; row < jsonArray.size(); ++row) {
          QJsonObject remoteInfo = jsonArray[row].toObject();
          OperationInfData* operationData;
          if (remoteInfo["type"].toInt() == 0) {
            operationData = new OperationInfData(
              remoteInfo["name"].toString(),
              (OperationInfData::operationType)remoteInfo["type"].toInt(),
              remoteInfo["commandStr"].toString(),
              remoteInfo["checkSuccessStr"].toString(),
              remoteInfo["checkErrorStr"].toString());
          }
          else {
            operationData = new OperationInfData(
              remoteInfo["name"].toString(),
              (OperationInfData::operationType)remoteInfo["type"].toInt(),
              remoteInfo["transferFileSourcePath"].toString(),
              remoteInfo["transferFileDestinationPath"].toString(),
              (OperationInfData::checkFileMethods)remoteInfo["checkFile"].toInt());
          }
          operationTable->setItem(row, 0,
            new QTableWidgetItem(operationData->name));
          operationTable->setItem(row, 1,
            new QTableWidgetItem(operationData->operationTypeString()));
          if (operationData->type == OperationInfData::operationCommand)
            operationTable->setItem(row, 2,
              new QTableWidgetItem(operationData->commandStr));
          else
            operationTable->setItem(row, 2,
              new QTableWidgetItem(operationData->transferFileSourcePath));
          QSharedPointer<OperationInfData> shareOperationInfData(operationData);
          QVariant variant = QVariant::fromValue(shareOperationInfData);
          operationTable->item(row, 0)->setData(Qt::UserRole, variant);
          qDebug() << "Table data read from" << filePath;
        }
      }
      else
        QMessageBox::warning(this, "警告", "Invalid JSON data in file");
    }
    else
      QMessageBox::warning(this, "警告",
        "Failed to open file for reading:" + file.errorString().toLocal8Bit());
    remoteTable->blockSignals(false);
    operationTable->blockSignals(false);
    flashOperationTableItems(operationTable);
    emit remoteTable->itemChanged(remoteTable->item(0, 0));
    emit operationTable->itemChanged(operationTable->item(0, 0));
  }
}
void MainWindow::on_pushButtonOpenJson_clicked() {
  QString openFilePath = QFileDialog::getOpenFileName(nullptr, "Open JSON File",
      QDir::homePath(), "JSON Files (*.json)");
  if (!openFilePath.isEmpty())
    readTableDataFromJson(ui->tableWidgetRemote, ui->tableWidgetOperation,
      openFilePath);
}
void MainWindow::cloneRemoteTableSelectRow(QTableWidget* tableWidget) {
  int selectedRow = tableWidget->currentRow();
  int columnCount = tableWidget->columnCount();
  tableWidget->blockSignals(true);
  if (selectedRow >= 0) {
    tableWidget->insertRow(selectedRow + 1);
    for (int col = 0; col < columnCount; ++col) {
      QTableWidgetItem* item = tableWidget->item(selectedRow, col);
      QTableWidgetItem* newItem = new QTableWidgetItem(*item);
      if (col == 0) {
        QVariant customDataVariant = item->data(Qt::UserRole);
        QSharedPointer<RemoteInfData> sharePointer =
          customDataVariant.value < QSharedPointer<RemoteInfData>>();
        RemoteInfData* remoteData = new RemoteInfData(*sharePointer.data());
        QSharedPointer<RemoteInfData> shareRemoteInfData(remoteData);
        QVariant variant = QVariant::fromValue(shareRemoteInfData);
        newItem->setData(Qt::UserRole, variant);
      }
      else if (col == 1) {
        QVariant customDataVariant = item->data(Qt::UserRole);
        QSharedPointer<QString> sharePointer =
          customDataVariant.value < QSharedPointer<QString>>();
        QString* sshRunLog = new QString(*sharePointer.data());
        QSharedPointer<QString> sharedSshRunLog(sshRunLog);
        QVariant variantRunLog = QVariant::fromValue(sharedSshRunLog);
        newItem->setData(Qt::UserRole, variantRunLog);
      }
      tableWidget->setItem(selectedRow + 1, col, newItem);
    }
  }
  tableWidget->blockSignals(false);
}
void MainWindow::cloneOperationTableSelectRow(QTableWidget* tableWidget) {
  int selectedRow = tableWidget->currentRow();
  int columnCount = tableWidget->columnCount();
  tableWidget->blockSignals(true);
  if (selectedRow >= 0) {
    tableWidget->insertRow(selectedRow + 1);
    for (int col = 0; col < columnCount; ++col) {
      QTableWidgetItem* item = tableWidget->item(selectedRow, col);
      QTableWidgetItem* newItem = new QTableWidgetItem(*item);
      if (col == 0) {
        QVariant customDataVariant = item->data(Qt::UserRole);
        QSharedPointer<OperationInfData> sharePointer =
          customDataVariant.value < QSharedPointer<OperationInfData>>();
        OperationInfData* remoteData = new OperationInfData(*sharePointer.data());
        QSharedPointer<OperationInfData> shareRemoteInfData(remoteData);
        QVariant variant = QVariant::fromValue(shareRemoteInfData);
        newItem->setData(Qt::UserRole, variant);
      }
      tableWidget->setItem(selectedRow + 1, col, newItem);
    }
  }
  tableWidget->blockSignals(false);
}
void MainWindow::removeTableWidgetSelectRow(QTableWidget* tableWidget) {
  int selectedRow = tableWidget->currentRow();
  int rowNum = tableWidget->rowCount();
  if ((selectedRow >= 0) && (rowNum > 1))
    tableWidget->removeRow(selectedRow);
}
void MainWindow::on_comboBoxJson_currentTextChanged(const QString& arg1) {
  QString filePath = ":/resources/batchConf/" + arg1;
  qDebug() << "Load preset configuration file: " << arg1;
  if (!filePath.isEmpty())
    readTableDataFromJson(ui->tableWidgetRemote, ui->tableWidgetOperation,
      filePath);
}
void MainWindow::on_pushButtonSaveOneOperation_clicked() {
  int selectedRow = ui->tableWidgetOperation->currentRow();
  QVariant customDataVariant = ui->tableWidgetOperation->item(selectedRow,
      0)->data(Qt::UserRole);
  QSharedPointer<OperationInfData> sharePointer =
    customDataVariant.value < QSharedPointer<OperationInfData>>();
  OperationInfData* operationData = sharePointer.data();
  operationData->type = (OperationInfData::operationType)
    ui->tabWidgetOperation->currentIndex();
  operationData->name = ui->lineEditOperationName->text();
  switch (operationData->type) {
  case OperationInfData::operationCommand:
    operationData->commandStr = ui->lineEditCommandStr->text();
    operationData->checkSuccessStr = ui->lineEditCommandSuccessCheck->text();
    operationData->checkErrorStr = ui->lineEditCommandErrorCheck->text();
    break;
  case OperationInfData::operationUpFile:
    operationData->transferFileSourcePath = ui->lineEditUpfile->text();
    operationData->transferFileDestinationPath = ui->lineEditUpRemotePath->text();
    operationData->checkFile = OperationInfData::checkFileMd5;
    break;
  case OperationInfData::operationDownFile:
    operationData->transferFileSourcePath = ui->lineEditDownRemoteFile->text();
    operationData->transferFileDestinationPath = ui->lineEditDownDirPath->text();
    operationData->checkFile = OperationInfData::checkFileMd5;
    break;
  }
  flashOperationTableItems(ui->tableWidgetOperation);
  emit ui->tableWidgetOperation->itemSelectionChanged();
  enableEditOperation(false);
}
void MainWindow::flashOperationTableItems(QTableWidget* tableWidget) {
  int rowCount = tableWidget->rowCount();
  for (int row = 0; row < rowCount; row++) {
    QVariant customDataVariant = tableWidget->item(row, 0)->data(Qt::UserRole);
    QSharedPointer<OperationInfData> sharePointer =
      customDataVariant.value <QSharedPointer<OperationInfData>>();
    OperationInfData* operationData = sharePointer.data();
    operationData->checkStatus();
    tableWidget->item(row, 0)->setText(operationData->name);
    tableWidget->item(row, 1)->setText(operationData->operationTypeString());
    switch (operationData->type) {
    case OperationInfData::operationCommand:
      if (operationData->status == true)
        tableWidget->item(row, 2)->setText(operationData->commandStr);
      else
        tableWidget->item(row, 2)->setText("该项配置不完整，将不会执行");
      break;
    case OperationInfData::operationUpFile:
    case OperationInfData::operationDownFile:
      if (operationData->status == true)
        tableWidget->item(row, 2)->setText(operationData->transferFileSourcePath);
      else
        tableWidget->item(row, 2)->setText("该项配置不完整，将不会执行");
      break;
    }
  }
}
void MainWindow::flashRemoteTableDatas(QTableWidget* tableWidget) {
  int rowCount = tableWidget->rowCount();
  for (int row = 0; row < rowCount; row++) {
    QVariant customDataVariant = tableWidget->item(row, 0)->data(Qt::UserRole);
    QSharedPointer<RemoteInfData> sharePointer =
      customDataVariant.value <QSharedPointer<RemoteInfData>>();
    RemoteInfData* remoteData = sharePointer.data();
    remoteData->ip = tableWidget->item(row, 0)->text();
    remoteData->port = tableWidget->item(row, 1)->text().toInt();
    remoteData->user = tableWidget->item(row, 2)->text();
    remoteData->passwd = tableWidget->item(row, 3)->text();
  }
}
void MainWindow::enableEdit(bool enable) {
  enableEditOperation(enable);
  ui->tableWidgetOperation->setEnabled(enable);
  if (enable)
    ui->tableWidgetRemote->setEditTriggers(QAbstractItemView::DoubleClicked);
  else
    ui->tableWidgetRemote->setEditTriggers(QAbstractItemView::NoEditTriggers);
  ui->pushButtonHelp->setEnabled(enable);
  ui->pushButtonRun->setEnabled(enable);
  ui->pushButtonOpenJson->setEnabled(enable);
  ui->pushButtonOpenRootPath->setEnabled(enable);
  ui->pushButtonSaveJson->setEnabled(enable);
  ui->comboBoxJson->setEnabled(enable);
  ui->comboBoxBatchMax->setEnabled(enable);
}
void MainWindow::enableEditOperation(bool enable) {
  ui->lineEditOperationName->setEnabled(enable);
  ui->tabWidgetOperation->setEnabled(enable);
  ui->pushButtonSaveOneOperation->setEnabled(enable);
}

void MainWindow::startBatch() {
  qint64 operationNum = ui->tableWidgetOperation->rowCount();
  if (startNum == remoteNum)
    return;
  if ((startNum - closeNum) < ui->comboBoxBatchMax->currentText().toUInt()) {
    qint64 maxBatch = startNum + ((ui->comboBoxBatchMax->currentText().toUInt()
          - (startNum - closeNum)));
    maxBatch = maxBatch > remoteNum ? remoteNum : maxBatch;
    for (; startNum < maxBatch; startNum += 1) {
      RemoteSSHOperation* remoteSSH = new RemoteSSHOperation(this);
      for (int rowOperation = 0; rowOperation < operationNum; ++rowOperation) {
        QVariant customDataVariant = ui->tableWidgetOperation->item(rowOperation,
            0)->data(Qt::UserRole);
        QSharedPointer<OperationInfData> sharePointer =
          customDataVariant.value <QSharedPointer<OperationInfData>>();
        OperationInfData* operationData = sharePointer.data();
        remoteSSH->addOperationInf(operationData);
      }
      ui->tableWidgetRemote->item(startNum,
        ui->tableWidgetRemote->columnCount() - 1)->setText("");
      QVariant customDataVariant = ui->tableWidgetRemote->item(startNum,
          0)->data(Qt::UserRole);
      QSharedPointer<RemoteInfData> sharePointer =
        customDataVariant.value <QSharedPointer<RemoteInfData>>();
      RemoteInfData* remoteData = sharePointer.data();
      remoteSSH->setInfo(remoteData, startNum, localDir);
      remoteSSH->start();
      changeColorTableRow(ui->tableWidgetRemote, startNum, runningColor);
    }
  }
}

void MainWindow::changeColorTableRow(QTableWidget* tableWidget, quint64 row,
  QColor color) {
  for (int col = 0; col < tableWidget->columnCount(); ++col) {
    QTableWidgetItem* item = tableWidget->item(row, col);
    if (item)
      item->setBackground(QBrush(color));
  }
}
void MainWindow::flashStatus(QString status, quint64 id) {
  qDebug() << "flashStatus " << "[" << id + 1 << "] " << status;
  ui->tableWidgetRemote->setItem(id, ui->tableWidgetRemote->columnCount() - 1,
    new QTableWidgetItem(status));
}
void MainWindow::comReturn(bool ok, quint64 id) {
  closeNum += 1;
  if (ui->tableWidgetRemote->item(id,
      ui->tableWidgetRemote->columnCount() - 1) == NULL)
    return;
  QString tempText;
  tempText += ok ? "成功|" : "错误|";
  tempText +=  ui->tableWidgetRemote->item(id,
      ui->tableWidgetRemote->columnCount() - 1)->text();
  ui->tableWidgetRemote->item(id,
    ui->tableWidgetRemote->columnCount() - 1)->setText(tempText);
  changeColorTableRow(ui->tableWidgetRemote, id, ok ? sucessColor : errorColor);
  if (closeNum == remoteNum)
    enableEdit(true);
  startBatch();
}
void MainWindow::WarningMessage(QString message, quint64 id) {
  if (!(message.contains("error", Qt::CaseInsensitive) ||
      message.contains("warning", Qt::CaseInsensitive)))
    flashStatus(message, id);
  QMessageBox::warning(this, "警告",
    QString("[%1] %2").arg(id + 1).arg(message));
}
void MainWindow::returnComLog(QString message, quint64 id) {
  qDebug() << "returnComLog " << "[" << id + 1 << "] " << message;
  //ui->textEditSshinfo->append(QString("[%1] %2").arg(id + 1).arg(message));
  QVariant customDataVariant = ui->tableWidgetRemote->item(id,
      1)->data(Qt::UserRole);
  QSharedPointer<QString> sharePointer =
    customDataVariant.value <QSharedPointer<QString>>();
  QString* sshRunLog = sharePointer.data();
  sshRunLog->append(message);
}
void MainWindow::flashProgress(double progress, quint64 id) {
  if (ui->tableWidgetRemote->item(id,
      ui->tableWidgetRemote->columnCount() - 1) == NULL)
    return;
  QStringList tempStrList = ui->tableWidgetRemote->item(id,
      ui->tableWidgetRemote->columnCount() - 1)->text().split("|");
  QString tempText = QString::number(progress * 100, 'd',
      2) + "%" + "|" + tempStrList.at(tempStrList.size() > 1 ? 1 : 0);
  ui->tableWidgetRemote->item(id,
    ui->tableWidgetRemote->columnCount() - 1)->setText(tempText);
}
void MainWindow::on_pushButtonRun_clicked() {
  qint64 operationNum = ui->tableWidgetOperation->rowCount();
  remoteNum = ui->tableWidgetRemote->rowCount();
  for (int row = 0; row < remoteNum; ++row) {
    for (int column = 0; column < 4; ++column) {
      if (ui->tableWidgetRemote->item(row, column) == NULL) {
        QMessageBox::warning(this, "警告", "远程设备配置表格中有空行");
        return;
      }
    }
    changeColorTableRow(ui->tableWidgetRemote, row, noneColor);
  }
  closeNum = 0;
  startNum = 0;
  enableEdit(false);
  flashOperationTableItems(ui->tableWidgetOperation);
  flashRemoteTableDatas(ui->tableWidgetRemote);
  md5SumAll(ui->tableWidgetOperation);
  startBatch();
}
void MainWindow::on_pushButtonUpfile_clicked() {
  QString relativePath = QFileDialog::getOpenFileName(nullptr,
      "Select Relative Path", localDir.path(), "All Files (*.*)");
  if (!relativePath.isEmpty()) {
    QString fullPath = QDir(localDir.path()).absoluteFilePath(relativePath);
    QString relative = QDir(localDir.path()).relativeFilePath(fullPath);
    ui->lineEditUpfile->setText(relative);
    qDebug() << "Selected Relative Path:" << relative;
  }
  else
    qDebug() << "No file selected.";
}
void MainWindow::on_pushButtonDownfile_clicked() {
  QString selectedDirectory = QFileDialog::getExistingDirectory(nullptr,
      "Select Directory", localDir.path());
  if (!selectedDirectory.isEmpty()) {
    QString relative = QDir(localDir.path()).relativeFilePath(selectedDirectory);
    ui->lineEditDownDirPath->setText(relative);
    qDebug() << "Selected Directory:" << relative;
  }
  else
    qDebug() << "No directory selected.";
}
QString MainWindow::calculateFileMD5(const QString& filePath) {
  QFile file(filePath);
  if (!file.open(QIODevice::ReadOnly)) {
    qDebug() << "Failed to open file.";
    return QString();
  }
  QCryptographicHash hash(QCryptographicHash::Md5);
  if (hash.addData(&file)) {
    QByteArray md5 = hash.result();
    return md5.toHex();
  }
  else {
    qDebug() << "Failed to calculate MD5.";
    return QString();
  }
}
void MainWindow::md5SumAll(QTableWidget* tableWidget) {
  qint64 operationNum = ui->tableWidgetOperation->rowCount();
  for (int rowOperation = 0; rowOperation < operationNum; ++rowOperation) {
    QVariant customDataVariant = ui->tableWidgetOperation->item(rowOperation,
        0)->data(Qt::UserRole);
    QSharedPointer<OperationInfData> sharePointer =
      customDataVariant.value <QSharedPointer<OperationInfData>>();
    OperationInfData* operationData = sharePointer.data();
    if (operationData->type == OperationInfData::operationUpFile) {
      QString absolutePath = QDir(localDir).absoluteFilePath(
          operationData->transferFileSourcePath);
      QString md5Str = calculateFileMD5(absolutePath);
      qDebug() << "md5sum " << absolutePath << " -> " << md5Str;
      operationData->fileMd5 = md5Str;
    }
  }
}
void MainWindow::on_pushButtonSaveJson_clicked() {
  QString saveFilePath = QFileDialog::getSaveFileName(nullptr, "Save JSON File",
      QDir::homePath(), "JSON Files (*.json)");
  if (!saveFilePath.isEmpty())
    writeTableDataToJson(ui->tableWidgetRemote, ui->tableWidgetOperation,
      saveFilePath);
}

void MainWindow::on_pushButtonOpenDown_clicked() {
  QString absolutePath = QDir::cleanPath(QDir(localDir).absoluteFilePath(
        ui->lineEditDownDirPath->text()));
  bool success = QDesktopServices::openUrl(absolutePath);
  if (!success)
    qDebug() << "Failed to open directory.";
}

void MainWindow::on_pushButtonHelp_clicked()
{

    maskWidget->setStyleSheet("background-color:rgba(0,0,0,0)");
    maskWidget->setGeometry(0, 0, this->width(), this->height());
    maskWidget->show();
    maskWidgetisShow = 1;

    maskLabelTop->setStyleSheet("background-color:rgba(0,0,0,0.6)");
    maskLabelLeft->setStyleSheet("background-color:rgba(0,0,0,0.6)");
    maskLabelRight->setStyleSheet("background-color:rgba(0,0,0,0.6)");
    maskLabelBottom->setStyleSheet("background-color:rgba(0,0,0,0.6)");



    nextButton->move(this->width() - 100, this->height() - 50);
    nextButton->resize(100, 50);
    nextButton->setStyleSheet("background-color:rgba(255,255,255,1)");


    helpInformation->setStyleSheet("background-color:rgba(255,255,255,0.6);color:red;");


    helpInfoList = {"①通过这里指定执行的根目录",
                    "②在这里配置需要进行批量部署的设备，右键点击已有设备，可进行设备的克隆或删除，通过修改克隆项进行设备的添加",
                    "③在这里对每台设备需要执行的操作进行配置，右键点击已有操作，可对已有操作进行克隆或删除，通过修改克隆项进行操作的添加",
                    "④可添加的操作为三类，分别为：1.命令下发；2.文件上传；文件下载；",
                    "1. 命令下发为在需要批量操作的设备上执行对应设备；\n2. 文件上传为将本地文件上传至需要批量操作的设备；\n3. 文件下载为将需要批量操作的设备上的文件下载至本地路径；",
                    "⑤在配置完成后，可以使用左侧的存储按钮将配置信息储存为json文件，方便之后使用；",
                    "⑥也可以使用右侧的读取按钮读取之前存储的配置文件；",
                    "⑦程序内预置了SE6相关基本配置，可以在这里进行选取；",
                    "⑧可以在此处修改最大并行上限，可以对批量部署过程使用的资源进行限制；",
                    "⑨点击此处开始执行批量部署；",
                    "⑩执行结束后的结果会打印在此处，不同的设备之间采用分页的方式进行表示；"};

    connect(nextButton, &QPushButton::clicked, this, [this]{
//        qDebug() << helpCnt;
        helpCnt ++;

        if(helpCnt == 11){
            closeHelp();
            maskWidget->close();
            maskWidgetisShow = 0;
            helpCnt = 0;
            cnt1 = 0;
            cnt2 = 0;
            cnt3 = 0;
            nextButton->setText("下一步");
//            disconnect(nextButton, 0, 0, 0);
            nextButton->disconnect();
        }
        else if(helpCnt == 1 || helpCnt == 2 || helpCnt == 3 || helpCnt == 4 || helpCnt == 10){
            closeHelp();
            maskHelpRegion(getPos1(list2[cnt2]));
            cnt2++;
            if(helpCnt == 10){
                nextButton->setText("完成");
            }
        }
        else if(helpCnt == 5 || helpCnt == 6 || helpCnt == 9){
            closeHelp();
            maskHelpRegion(getPos1(list3[cnt3]));
            cnt3++;
        }
        else{
            closeHelp();
            maskHelpRegion(getPos2(list1[cnt1]));
            cnt1++;
        }
    });

    maskHelpRegion(getPos2(ui->horizontalLayout_4));

}

void MainWindow::maskHelpRegion(QList<qint64> a)
{

    qint64 x = a[0];
    qint64 y = a[1];
    qint64 w = a[2];
    qint64 h = a[3];

    maskLabelTop->setGeometry(x, 0, w, y);
    maskLabelLeft->setGeometry(0, 0, x, this->height());
    maskLabelRight->setGeometry(x + w, 0, this->width() - x - w, this->height());
    maskLabelBottom->setGeometry(x, y + h, w, this->height() - y - h);


    helpInformation->setText(helpInfoList[helpCnt]);

    helpInformation->resize(this->width() - 250, 75);
    helpInformation->move(125, this->height() - 75);
    helpInformation->setAlignment(Qt::AlignVCenter);
    helpInformation->setWordWrap(true);

    maskLabelTop->show();
    maskLabelLeft->show();
    maskLabelRight->show();
    maskLabelBottom->show();
    nextButton->show();
    helpInformation->show();

}


void MainWindow::closeHelp(){
    maskLabelTop->close();
    maskLabelLeft->close();
    maskLabelRight->close();
    maskLabelBottom->close();
    helpInformation->close();
    nextButton->close();
}


QList<qint64> MainWindow::getPos1(QWidget *a){
    QList<qint64> res;
    qint64 x;
    qint64 y;
    if(a->parentWidget()){
        x = a->pos().x() + getPos1(a->parentWidget())[0];
        y = a->pos().y() + getPos1(a->parentWidget())[1];
    }else{
        return {0, 0, 0, 0};
    }
    qint64 w = a->geometry().width();
    qint64 h = a->geometry().height();
    res << x << y << w << h;
    return res;
}

QList<qint64> MainWindow::getPos2(QLayout *a){
    QList<qint64> res;
    qint64 x = a->geometry().x();
    qint64 y = a->geometry().y();
    qint64 w = a->geometry().width();
    qint64 h = a->geometry().height();
    res << x << y << w << h;
    return res;
}

void MainWindow::resizeEvent(QResizeEvent *event){
    if(maskWidgetisShow){
//        qDebug() << helpCnt;
        qint64 x = 0;
        qint64 y = 0;
        qint64 w = 0;
        qint64 h = 0;
        QList<qint64> tmp;

        maskWidget->resize(this->width(), this->height());
        nextButton->move(this->width() - 100, this->height() - 50);
        if(helpCnt == 1 || helpCnt == 2 || helpCnt == 3 || helpCnt == 4 || helpCnt == 10){
            tmp = getPos1(list2[cnt2-1]);
        }
        else if(helpCnt == 5 || helpCnt == 6 || helpCnt == 9){
            tmp = getPos1(list3[cnt3-1]);
        }
        else if(helpCnt == 0){
            tmp = getPos2(ui->horizontalLayout_4);
        }
        else{
            tmp = getPos2(list1[cnt1-1]);
        }

        x = tmp[0];
        y = tmp[1];
        w = tmp[2];
        h = tmp[3];

        maskLabelTop->setGeometry(x, 0, w, y);
        maskLabelLeft->setGeometry(0, 0, x, this->height());
        maskLabelRight->setGeometry(x + w, 0, this->width() - x - w, this->height());
        maskLabelBottom->setGeometry(x, y + h, w, this->height() - y - h);
        helpInformation->resize(this->width() - 250, 75);
        helpInformation->move(125, this->height() - 75);

    }
};
