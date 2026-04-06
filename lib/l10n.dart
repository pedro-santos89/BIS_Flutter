import 'package:flutter/material.dart';

/// Custom localization class that provides English (en) and Portuguese (pt) translations.
/// Access in widgets via: AppLocalizations.of(context).tr('key')
///
/// To add a new translation key:
///   1. Add the key/value to both [_en] and [_pt] maps below.
///   2. Use tr('key') in your widget code.
///   For templates with variables, use trArgs('key', {'var': 'value'}).
class AppLocalizations {
  /// The locale this instance was created for.
  final Locale locale;

  AppLocalizations(this.locale);

  /// Shortcut to get the AppLocalizations from the current BuildContext.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// The delegate to register with MaterialApp.localizationsDelegates.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Convenience getter for the current language code ('en' or 'pt').
  String get languageCode => locale.languageCode;

  /// Looks up a translation by [key]. Falls back to English, then to the key itself.
  String tr(String key) => _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key] ?? key;

  /// Translates [key] and replaces {placeholder} tokens with values from [args].
  /// Example: trArgs('greeting', {'name': 'Pedro'}) turns 'Hello, {name}!' into 'Hello, Pedro!'
  String trArgs(String key, Map<String, String> args) {
    var text = tr(key);
    args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  /// Maps language codes to their translation dictionaries.
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': _en,
    'pt': _pt,
  };

  // ─── English translation map ───
  // Keys are organized by section: Common, Home, Login, Register, Admin,
  // Member List, Daily Member, Report, Custom Tables, User Management, PDF/Export.
  static const Map<String, String> _en = {
    // App
    'appTitle': 'BIS - BUS Information System',

    // Common
    'cancel': 'Cancel',
    'delete': 'Delete',
    'deleteAll': 'Delete All',
    'save': 'Save',
    'create': 'Create',
    'edit': 'Edit',
    'add': 'Add',
    'confirm': 'Confirm',
    'import': 'Import',
    'required': 'Required',
    'errorPrefix': 'Error: {error}',
    'yes': 'Yes',
    'no': 'No',
    'name': 'Name',
    'email': 'Email',
    'notes': 'Notes',
    'actions': 'Actions',
    'id': 'ID',
    'created': 'Created',
    'search': 'Search...',
    'rowsPerPage': 'Rows per page: ',
    'pageOf': 'Page {current} of {total}',
    'selected': '{count} selected',

    // Text size menu
    'textSizeIncrease': 'Increase',
    'textSizeDecrease': 'Decrease',
    'textSizeReset': 'Reset ({percent}%)',

    // Theme toggle
    'switchToLight': 'Switch to Light',
    'switchToDark': 'Switch to Dark',

    // Home
    'welcomeTitle': 'Welcome to bis',
    'welcomeSubtitle': '(BUS Information System)',
    'welcomeDescription': 'Manage members and registrations.',
    'memberRegistration': 'Member Registration',
    'dailyMemberRegistration': 'Daily Member Registration',
    'adminArea': 'Admin area',
    'logout': 'Logout',

    // Login
    'adminLogin': 'Admin Login',
    'home': 'Home',
    'username': 'Username',
    'password': 'Password',
    'logIn': 'Log In',
    'invalidCredentials': 'Invalid credentials',

    // Register - Member
    'dailyMemberRegistrationLink': 'Daily member registration',
    'nameRequired': 'Name is required',
    'emailOptional': 'Email (Optional)',
    'communicationCheckbox': 'I want to receive communications from BUS with upcoming events and news',
    'annualFeePaid': 'Annual fee paid',
    'register': 'Register',

    // Register - Daily
    'memberRegistrationLink': 'Member registration',
    'notesOptional': 'Notes (Optional)',

    // Registration Success
    'registrationComplete': 'Registration Complete',
    'congratsName': 'Congratulations, {name}!',
    'yourMemberNumber': 'Your member number is: {number}',
    'welcomeName': 'Welcome, {name}!',
    'yourDailyMemberNumber': 'Your daily member number is: {number}',
    'backToHome': 'Back to Home',

    // Admin
    'bisAdministration': 'BIS Administration',
    'logoutUser': 'Logout ({username})',
    'siteAdministration': 'Site administration',
    'welcomeUser': 'Welcome, {username}.',
    'sectionRegistry': 'REGISTRY',
    'members': 'Members',
    'membersSubtitle': 'View, add, edit and export members',
    'dailyMembers': 'Daily Members',
    'dailyMembersSubtitle': 'View, add, edit and export daily members',
    'registrationsReport': 'Registrations Report',
    'reportSubtitle': 'View new registrations by date range',
    'sectionCustomTables': 'CUSTOM TABLES',
    'manageCustomTables': 'Manage Custom Tables',
    'customTablesSubtitle': 'Create, edit and delete custom tables',
    'columnsCount': '{count} column(s)',
    'sectionUserManagement': 'USER MANAGEMENT',
    'users': 'Users',
    'usersSubtitle': 'Create, edit and manage user accounts',
    'sectionQuickActions': 'QUICK ACTIONS',
    'addMember': 'Add Member',
    'addDailyMember': 'Add Daily Member',
    'sectionDatabase': 'DATABASE',
    'exportDatabase': 'Export Database',
    'importDatabase': 'Import Database',
    'importDatabaseMessage': 'This will add records from the backup file to the database. Existing records will not be deleted. Continue?',
    'databaseExported': 'Database exported to {path}',
    'importedResult': 'Imported {members} members, {dailyMembers} daily members ({errors} errors)',

    // Member List
    'searchMembers': 'Search members...',
    'memberNumber': 'Member #',
    'communication': 'Comm.',
    'fee': 'Fee',
    'createdLisbon': 'Created (Lisbon)',
    'membersCount': '{count} member(s)',
    'noMembersFound': 'No members found',
    'exportSelectedCsv': 'Export selected to CSV',
    'exportAllCsv': 'Export ALL to CSV',
    'exportSelectedPdf': 'Export selected to PDF',
    'exportAllPdf': 'Export ALL to PDF',
    'importFromCsv': 'Import from CSV',
    'deleteSelected': 'Delete selected',
    'deleteAllCaps': 'Delete ALL',
    'noMembersSelectedExport': 'No members selected for export',
    'exportedMembersCsv': 'Exported {count} members to {path}',
    'pdfExported': 'PDF exported to {path}',
    'csvImportResult': 'CSV import: {created} created, {updated} updated, {errors} errors',
    'deleteMember': 'Delete Member',
    'deleteMemberConfirm': 'Delete "{name}" (#{number})?',
    'deleteSelectedMembers': 'Delete Selected Members',
    'deleteSelectedMembersConfirm': 'Delete {count} selected member(s)? This cannot be undone.',
    'deletedMembers': 'Deleted {count} member(s)',
    'deleteAllMembers': 'Delete ALL Members',
    'deleteAllMembersConfirm': 'This will permanently delete ALL members from the database. This cannot be undone.\n\nAre you sure?',
    'noMembersSelected': 'No members selected',

    // Member Edit
    'editMember': 'Edit Member',
    'memberInfo': 'Member #{number} (ID: {id})',
    'memberNumberLabel': 'Member number (auto-assigned if empty)',
    'communicationLabel': 'Communication',
    'memberCreated': 'Member created',
    'memberSaved': 'Member saved',

    // Daily Member List
    'searchDailyMembers': 'Search...',
    'dailyNumber': 'Daily #',
    'dailyMembersCount': '{count} daily member(s)',
    'noDailyMembersFound': 'No daily members found',
    'noDailyMembersSelectedExport': 'No daily members selected for export',
    'exportedDailyMembersCsv': 'Exported {count} daily members to {path}',
    'deleteDailyMember': 'Delete Daily Member',
    'deleteDailyMemberConfirm': 'Delete "{name}" (Daily #{number})?',
    'deleteSelectedDailyMembers': 'Delete Selected Daily Members',
    'deleteSelectedDailyMembersConfirm': 'Delete {count} selected daily member(s)? This cannot be undone.',
    'deletedDailyMembers': 'Deleted {count} daily member(s)',
    'deleteAllDailyMembers': 'Delete ALL Daily Members',
    'deleteAllDailyMembersConfirm': 'This will permanently delete ALL daily members from the database. This cannot be undone.\n\nAre you sure?',
    'noDailyMembersSelected': 'No daily members selected',

    // Daily Member Edit
    'addDailyMemberTitle': 'Add Daily Member',
    'editDailyMember': 'Edit Daily Member',
    'dailyMemberInfo': 'Daily #{number} (ID: {id})',
    'dailyMemberNumberLabel': 'Daily member number (auto-assigned if empty)',
    'dailyMemberCreated': 'Daily member created',
    'dailyMemberSaved': 'Daily member saved',

    // Report
    'period': 'Period: ',
    'to': 'to',
    'quickRange': 'Quick range',
    'today': 'Today',
    'last7Days': 'Last 7 days',
    'thisMonth': 'This month',
    'thisYear': 'This year',
    'allTime': 'All time',
    'newRegistrations': 'New Registrations',
    'registrationsTitle': '{title} — {total} new registration(s)',
    'noRegistrations': 'No registrations in this period.',
    'date': 'Date',

    // Custom Tables
    'customTables': 'Custom Tables',
    'createTable': 'Create Table',
    'noCustomTables': 'No custom tables yet',
    'noCustomTablesHint': 'Tap + to create your first table',
    'columnsDetail': '{count} column(s): {names}',
    'editStructure': 'Edit structure',
    'deleteTable': 'Delete table',
    'deleteTableTitle': 'Delete Table',
    'deleteTableConfirm': 'Delete table "{name}" and ALL its data? This cannot be undone.',

    // Custom Table Design
    'createCustomTable': 'Create Custom Table',
    'editTableStructure': 'Edit Table Structure',
    'newCustomTable': 'New Custom Table',
    'editTableName': 'Edit "{name}"',
    'editWarning': 'Warning: Editing the table structure will delete all existing data in this table.',
    'tableName': 'Table Name',
    'tableNameHint': 'e.g. Volunteers, Equipment, Events',
    'columns': 'Columns',
    'addColumn': 'Add Column',
    'columnName': 'Column Name',
    'type': 'Type',
    'typeText': 'Text',
    'typeInteger': 'Integer',
    'typeDecimal': 'Decimal',
    'typeYesNo': 'Yes/No',
    'typeDate': 'Date',
    'typeDateHour': 'Date+Hour',
    'selectDate': 'Select date',
    'selectDateTime': 'Select date and time',
    'removeColumn': 'Remove column',
    'saveChanges': 'Save Changes',

    // Custom Table Data
    'noTableSelected': 'No table selected',
    'rowsCount': '{count} row(s)',
    'noRowsFound': 'No rows found',
    'addRow': 'Add Row',
    'editRow': 'Edit Row',
    'enterNumber': 'Enter a number',
    'enterDecimal': 'Enter a decimal',
    'enterText': 'Enter text',
    'deleteRow': 'Delete Row',
    'deleteRowConfirm': 'Delete row #{id}?',
    'deleteSelectedRows': 'Delete Selected Rows',
    'deleteSelectedRowsConfirm': 'Delete {count} selected row(s)? This cannot be undone.',
    'deletedRows': 'Deleted {count} row(s)',
    'deleteAllRows': 'Delete ALL Rows',
    'deleteAllRowsConfirm': 'This will permanently delete ALL rows. This cannot be undone.',
    'noRowsSelectedExport': 'No rows selected for export',
    'exportedRowsCsv': 'Exported {count} rows to {path}',
    'csvImportRowsResult': 'CSV import: {created} created, {errors} errors',

    // User Management
    'userManagement': 'User Management',
    'createUser': 'Create User',
    'noUsersFound': 'No users found',
    'administrator': 'Administrator',
    'normalUser': 'Normal User',
    'demoteToNormal': 'Demote to normal user',
    'promoteToAdmin': 'Promote to admin',
    'changePassword': 'Change password',
    'deleteUser': 'Delete user',
    'changePasswordTitle': 'Change Password: {username}',
    'newPassword': 'New Password',
    'changePasswordButton': 'Change Password',
    'passwordChanged': 'Password changed for {username}',
    'changeRole': 'Change Role',
    'changeRoleConfirm': 'Change "{username}" to {role}?',
    'admin': 'Admin',
    'deleteUserTitle': 'Delete User',
    'deleteUserConfirm': 'Delete user "{username}"? This cannot be undone.',
    'deletedUser': 'Deleted user "{username}"',
    'editUser': 'Edit User',
    'adminSwitch': 'Admin',
    'adminSwitchSubtitleOn': 'Can manage users and all features',
    'adminSwitchSubtitleOff': 'Standard user access',

    // PDF / Export
    'noRecordsToExport': 'No records to export',
    'exported': 'Exported: {date}',
    'totalRecords': 'Total: {count} records',
    'pageOfTotal': 'Page {page} of {total}',
    'saveCsvFile': 'Save CSV file',
    'selectCsvFile': 'Select CSV file',
    'exportDatabaseFile': 'Export Database',
    'importDatabaseBackup': 'Import Database Backup',
    'savePdfFile': 'Save PDF file',
  };

  // ─── Portuguese translation map ───
  // Must contain the same keys as [_en]. Uses 'sócio(s)' for 'member(s)'.
  static const Map<String, String> _pt = {
    // App
    'appTitle': 'BIS - Sistema de Informação BUS',

    // Common
    'cancel': 'Cancelar',
    'delete': 'Eliminar',
    'deleteAll': 'Eliminar Tudo',
    'save': 'Guardar',
    'create': 'Criar',
    'edit': 'Editar',
    'add': 'Adicionar',
    'confirm': 'Confirmar',
    'import': 'Importar',
    'required': 'Obrigatório',
    'errorPrefix': 'Erro: {error}',
    'yes': 'Sim',
    'no': 'Não',
    'name': 'Nome',
    'email': 'Email',
    'notes': 'Notas',
    'actions': 'Ações',
    'id': 'ID',
    'created': 'Criado',
    'search': 'Pesquisar...',
    'rowsPerPage': 'Linhas por página: ',
    'pageOf': 'Página {current} de {total}',
    'selected': '{count} selecionado(s)',

    // Text size menu
    'textSizeIncrease': 'Aumentar',
    'textSizeDecrease': 'Diminuir',
    'textSizeReset': 'Repor ({percent}%)',

    // Theme toggle
    'switchToLight': 'Mudar para Claro',
    'switchToDark': 'Mudar para Escuro',

    // Home
    'welcomeTitle': 'Bem-vindo ao bis',
    'welcomeSubtitle': '(Sistema de Informação BUS)',
    'welcomeDescription': 'Gerir sócios e registos.',
    'memberRegistration': 'Registo de Sócio',
    'dailyMemberRegistration': 'Registo de Sócio Diário',
    'adminArea': 'Área de administração',
    'logout': 'Sair',

    // Login
    'adminLogin': 'Login de Administrador',
    'home': 'Início',
    'username': 'Nome de utilizador',
    'password': 'Palavra-passe',
    'logIn': 'Entrar',
    'invalidCredentials': 'Credenciais inválidas',

    // Register - Member
    'dailyMemberRegistrationLink': 'Registo de sócio diário',
    'nameRequired': 'O nome é obrigatório',
    'emailOptional': 'Email (Opcional)',
    'communicationCheckbox': 'Quero receber comunicações do BUS sobre eventos e novidades',
    'annualFeePaid': 'Quota anual paga',
    'register': 'Registar',

    // Register - Daily
    'memberRegistrationLink': 'Registo de sócio',
    'notesOptional': 'Notas (Opcional)',

    // Registration Success
    'registrationComplete': 'Registo Completo',
    'congratsName': 'Parabéns, {name}!',
    'yourMemberNumber': 'O seu número de sócio é: {number}',
    'welcomeName': 'Bem-vindo, {name}!',
    'yourDailyMemberNumber': 'O seu número de sócio diário é: {number}',
    'backToHome': 'Voltar ao Início',

    // Admin
    'bisAdministration': 'Administração BIS',
    'logoutUser': 'Sair ({username})',
    'siteAdministration': 'Administração do site',
    'welcomeUser': 'Bem-vindo, {username}.',
    'sectionRegistry': 'REGISTO',
    'members': 'Sócios',
    'membersSubtitle': 'Ver, adicionar, editar e exportar sócios',
    'dailyMembers': 'Sócios Diários',
    'dailyMembersSubtitle': 'Ver, adicionar, editar e exportar sócios diários',
    'registrationsReport': 'Relatório de Registos',
    'reportSubtitle': 'Ver novos registos por intervalo de datas',
    'sectionCustomTables': 'TABELAS PERSONALIZADAS',
    'manageCustomTables': 'Gerir Tabelas Personalizadas',
    'customTablesSubtitle': 'Criar, editar e eliminar tabelas personalizadas',
    'columnsCount': '{count} coluna(s)',
    'sectionUserManagement': 'GESTÃO DE UTILIZADORES',
    'users': 'Utilizadores',
    'usersSubtitle': 'Criar, editar e gerir contas de utilizadores',
    'sectionQuickActions': 'AÇÕES RÁPIDAS',
    'addMember': 'Adicionar Sócio',
    'addDailyMember': 'Adicionar Sócio Diário',
    'sectionDatabase': 'BASE DE DADOS',
    'exportDatabase': 'Exportar Base de Dados',
    'importDatabase': 'Importar Base de Dados',
    'importDatabaseMessage': 'Isto irá adicionar registos do ficheiro de cópia de segurança à base de dados. Os registos existentes não serão eliminados. Continuar?',
    'databaseExported': 'Base de dados exportada para {path}',
    'importedResult': 'Importados {members} sócios, {dailyMembers} sócios diários ({errors} erros)',

    // Member List
    'searchMembers': 'Pesquisar sócios...',
    'memberNumber': 'Sócio #',
    'communication': 'Com.',
    'fee': 'Quota',
    'createdLisbon': 'Criado (Lisboa)',
    'membersCount': '{count} sócio(s)',
    'noMembersFound': 'Nenhum sócio encontrado',
    'exportSelectedCsv': 'Exportar selecionados para CSV',
    'exportAllCsv': 'Exportar TODOS para CSV',
    'exportSelectedPdf': 'Exportar selecionados para PDF',
    'exportAllPdf': 'Exportar TODOS para PDF',
    'importFromCsv': 'Importar de CSV',
    'deleteSelected': 'Eliminar selecionados',
    'deleteAllCaps': 'Eliminar TODOS',
    'noMembersSelectedExport': 'Nenhum sócio selecionado para exportação',
    'exportedMembersCsv': '{count} sócios exportados para {path}',
    'pdfExported': 'PDF exportado para {path}',
    'csvImportResult': 'Importação CSV: {created} criados, {updated} atualizados, {errors} erros',
    'deleteMember': 'Eliminar Sócio',
    'deleteMemberConfirm': 'Eliminar "{name}" (#{number})?',
    'deleteSelectedMembers': 'Eliminar Sócios Selecionados',
    'deleteSelectedMembersConfirm': 'Eliminar {count} sócio(s) selecionado(s)? Esta ação não pode ser revertida.',
    'deletedMembers': '{count} sócio(s) eliminado(s)',
    'deleteAllMembers': 'Eliminar TODOS os Sócios',
    'deleteAllMembersConfirm': 'Isto irá eliminar permanentemente TODOS os sócios da base de dados. Esta ação não pode ser revertida.\n\nTem a certeza?',
    'noMembersSelected': 'Nenhum sócio selecionado',

    // Member Edit
    'editMember': 'Editar Sócio',
    'memberInfo': 'Sócio #{number} (ID: {id})',
    'memberNumberLabel': 'Número de sócio (atribuído automaticamente se vazio)',
    'communicationLabel': 'Comunicação',
    'memberCreated': 'Sócio criado',
    'memberSaved': 'Sócio guardado',

    // Daily Member List
    'searchDailyMembers': 'Pesquisar...',
    'dailyNumber': 'Diário #',
    'dailyMembersCount': '{count} sócio(s) diário(s)',
    'noDailyMembersFound': 'Nenhum sócio diário encontrado',
    'noDailyMembersSelectedExport': 'Nenhum sócio diário selecionado para exportação',
    'exportedDailyMembersCsv': '{count} sócios diários exportados para {path}',
    'deleteDailyMember': 'Eliminar Sócio Diário',
    'deleteDailyMemberConfirm': 'Eliminar "{name}" (Diário #{number})?',
    'deleteSelectedDailyMembers': 'Eliminar Sócios Diários Selecionados',
    'deleteSelectedDailyMembersConfirm': 'Eliminar {count} sócio(s) diário(s) selecionado(s)? Esta ação não pode ser revertida.',
    'deletedDailyMembers': '{count} sócio(s) diário(s) eliminado(s)',
    'deleteAllDailyMembers': 'Eliminar TODOS os Sócios Diários',
    'deleteAllDailyMembersConfirm': 'Isto irá eliminar permanentemente TODOS os sócios diários da base de dados. Esta ação não pode ser revertida.\n\nTem a certeza?',
    'noDailyMembersSelected': 'Nenhum sócio diário selecionado',

    // Daily Member Edit
    'addDailyMemberTitle': 'Adicionar Sócio Diário',
    'editDailyMember': 'Editar Sócio Diário',
    'dailyMemberInfo': 'Diário #{number} (ID: {id})',
    'dailyMemberNumberLabel': 'Número de sócio diário (atribuído automaticamente se vazio)',
    'dailyMemberCreated': 'Sócio diário criado',
    'dailyMemberSaved': 'Sócio diário guardado',

    // Report
    'period': 'Período: ',
    'to': 'a',
    'quickRange': 'Intervalo rápido',
    'today': 'Hoje',
    'last7Days': 'Últimos 7 dias',
    'thisMonth': 'Este mês',
    'thisYear': 'Este ano',
    'allTime': 'Desde sempre',
    'newRegistrations': 'Novos Registos',
    'registrationsTitle': '{title} — {total} novo(s) registo(s)',
    'noRegistrations': 'Sem registos neste período.',
    'date': 'Data',

    // Custom Tables
    'customTables': 'Tabelas Personalizadas',
    'createTable': 'Criar Tabela',
    'noCustomTables': 'Nenhuma tabela personalizada',
    'noCustomTablesHint': 'Toque em + para criar a sua primeira tabela',
    'columnsDetail': '{count} coluna(s): {names}',
    'editStructure': 'Editar estrutura',
    'deleteTable': 'Eliminar tabela',
    'deleteTableTitle': 'Eliminar Tabela',
    'deleteTableConfirm': 'Eliminar a tabela "{name}" e TODOS os seus dados? Esta ação não pode ser revertida.',

    // Custom Table Design
    'createCustomTable': 'Criar Tabela Personalizada',
    'editTableStructure': 'Editar Estrutura da Tabela',
    'newCustomTable': 'Nova Tabela Personalizada',
    'editTableName': 'Editar "{name}"',
    'editWarning': 'Aviso: Editar a estrutura da tabela irá eliminar todos os dados existentes nesta tabela.',
    'tableName': 'Nome da Tabela',
    'tableNameHint': 'ex. Voluntários, Equipamento, Eventos',
    'columns': 'Colunas',
    'addColumn': 'Adicionar Coluna',
    'columnName': 'Nome da Coluna',
    'type': 'Tipo',
    'typeText': 'Texto',
    'typeInteger': 'Inteiro',
    'typeDecimal': 'Decimal',
    'typeYesNo': 'Sim/Não',
    'typeDate': 'Data',
    'typeDateHour': 'Data+Hora',
    'selectDate': 'Selecionar data',
    'selectDateTime': 'Selecionar data e hora',
    'removeColumn': 'Remover coluna',
    'saveChanges': 'Guardar Alterações',

    // Custom Table Data
    'noTableSelected': 'Nenhuma tabela selecionada',
    'rowsCount': '{count} linha(s)',
    'noRowsFound': 'Nenhuma linha encontrada',
    'addRow': 'Adicionar Linha',
    'editRow': 'Editar Linha',
    'enterNumber': 'Introduza um número',
    'enterDecimal': 'Introduza um decimal',
    'enterText': 'Introduza texto',
    'deleteRow': 'Eliminar Linha',
    'deleteRowConfirm': 'Eliminar linha #{id}?',
    'deleteSelectedRows': 'Eliminar Linhas Selecionadas',
    'deleteSelectedRowsConfirm': 'Eliminar {count} linha(s) selecionada(s)? Esta ação não pode ser revertida.',
    'deletedRows': '{count} linha(s) eliminada(s)',
    'deleteAllRows': 'Eliminar TODAS as Linhas',
    'deleteAllRowsConfirm': 'Isto irá eliminar permanentemente TODAS as linhas. Esta ação não pode ser revertida.',
    'noRowsSelectedExport': 'Nenhuma linha selecionada para exportação',
    'exportedRowsCsv': '{count} linhas exportadas para {path}',
    'csvImportRowsResult': 'Importação CSV: {created} criados, {errors} erros',

    // User Management
    'userManagement': 'Gestão de Utilizadores',
    'createUser': 'Criar Utilizador',
    'noUsersFound': 'Nenhum utilizador encontrado',
    'administrator': 'Administrador',
    'normalUser': 'Utilizador Normal',
    'demoteToNormal': 'Rebaixar para utilizador normal',
    'promoteToAdmin': 'Promover a administrador',
    'changePassword': 'Alterar palavra-passe',
    'deleteUser': 'Eliminar utilizador',
    'changePasswordTitle': 'Alterar Palavra-passe: {username}',
    'newPassword': 'Nova Palavra-passe',
    'changePasswordButton': 'Alterar Palavra-passe',
    'passwordChanged': 'Palavra-passe alterada para {username}',
    'changeRole': 'Alterar Papel',
    'changeRoleConfirm': 'Alterar "{username}" para {role}?',
    'admin': 'Administrador',
    'deleteUserTitle': 'Eliminar Utilizador',
    'deleteUserConfirm': 'Eliminar utilizador "{username}"? Esta ação não pode ser revertida.',
    'deletedUser': 'Utilizador "{username}" eliminado',
    'editUser': 'Editar Utilizador',
    'adminSwitch': 'Administrador',
    'adminSwitchSubtitleOn': 'Pode gerir utilizadores e todas as funcionalidades',
    'adminSwitchSubtitleOff': 'Acesso de utilizador padrão',

    // PDF / Export
    'noRecordsToExport': 'Sem registos para exportar',
    'exported': 'Exportado: {date}',
    'totalRecords': 'Total: {count} registos',
    'pageOfTotal': 'Página {page} de {total}',
    'saveCsvFile': 'Guardar ficheiro CSV',
    'selectCsvFile': 'Selecionar ficheiro CSV',
    'exportDatabaseFile': 'Exportar Base de Dados',
    'importDatabaseBackup': 'Importar Cópia de Segurança',
    'savePdfFile': 'Guardar ficheiro PDF',
  };
}

/// Localization delegate that tells Flutter which locales are supported.
/// Registered in MaterialApp.localizationsDelegates.
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
