import 'dart:async';

import 'package:flutter/material.dart';

import 'services/api_service.dart';

void main() {
  runApp(const BlockLedgerApp());
}

final api = ApiService();

const Color _background = Color(0xFFF5F8FC);
const Color _surface = Color(0xFFFFFFFF);
const Color _border = Color(0xFFE2E8F0);
const Color _cyan = Color(0xFF087FA5);

class BlockLedgerApp extends StatelessWidget {
  const BlockLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const scheme = ColorScheme.light(
      primary: _cyan,
      secondary: Color(0xFF168A68),
      surface: _surface,
      error: Color(0xFFB4233A),
    );
    return MaterialApp(
      title: 'BitTrade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: 'sans-serif',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
          ),
        ),
        scaffoldBackgroundColor: _background,
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: Color(0xFF172033),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: _surface,
          indicatorColor: Color(0xFFDDF4FA),
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _cyan,
          foregroundColor: Colors.white,
          elevation: 5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FBFD),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Map<String, dynamic>? _user;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final accessToken = await api.token;
      if (accessToken != null) _user = await api.me();
    } on Exception {
      await api.logout();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onSignedIn(Map<String, dynamic> user) => setState(() => _user = user);

  Future<void> _onSignOut() async {
    await api.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) return LoginScreen(onSignedIn: _onSignedIn);
    return DashboardScreen(user: _user!, onSignOut: _onSignOut);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onSignedIn, super.key});

  final ValueChanged<Map<String, dynamic>> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _register
          ? await api.register(_email.text.trim(), _password.text)
          : await api.login(_email.text.trim(), _password.text);
      widget.onSignedIn(user);
    } on Exception catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Brand(),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0F7FC)],
                      ),
                      border: Border.all(color: const Color(0xFFDCE8F2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3D8),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.currency_bitcoin,
                                color: Color(0xFFF0B74B),
                                size: 25,
                              ),
                            ),
                            const Spacer(),
                            const _ConnectionPill(),
                          ],
                        ),
                        const SizedBox(height: 19),
                        Text(
                          'Your crypto lab.',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Color(0xFF172033),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Practice trades. Explore blocks. Verify every transaction.',
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FeatureChip(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Virtual wallet',
                            ),
                            _FeatureChip(
                              icon: Icons.link,
                              label: 'Live ledger',
                            ),
                            _FeatureChip(
                              icon: Icons.verified_outlined,
                              label: 'Proof checks',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    _register ? 'Create your account' : 'Welcome back',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _register
                        ? 'Start with $100,000 in simulated funds.'
                        : 'Sign in to your virtual trading workspace.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 17),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.login),
                        label: Text('Sign in'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.person_add_alt_1),
                        label: Text('Create account'),
                      ),
                    ],
                    selected: {_register},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) => setState(() {
                              _register = selection.first;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 19),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: _password,
                    textInputAction:
                        _register ? TextInputAction.next : TextInputAction.done,
                    autofillHints: _register
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? 'Hide password' : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    obscureText: !_showPassword,
                    validator: (value) => value == null ||
                            value.length < (_register ? 10 : 1)
                        ? _register
                            ? 'Use at least 10 characters.'
                            : 'Enter your password.'
                        : null,
                  ),
                  if (_register) ...[
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (value) => value != _password.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F1),
                        border: Border.all(color: const Color(0xFFF2C9CE)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 17, color: Color(0xFFFF9AAA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFFFB0B8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              height: 17,
                              width: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _register
                                  ? Icons.rocket_launch_outlined
                                  : Icons.arrow_forward,
                            ),
                      label: Text(
                        _busy
                            ? 'Please wait…'
                            : _register
                                ? 'Create free account'
                                : 'Sign in securely',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Notice(
                    text:
                        'Simulation only. No real money or Bitcoin transactions. Create your own account; never share your password.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.onSignOut,
    super.key,
  });

  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  Map<String, dynamic>? _portfolio;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _audit = [];
  Map<String, dynamic>? _adminStats;
  List<Map<String, dynamic>> _adminUsers = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<dynamic>? _socketSubscription;
  final _verifyController = TextEditingController();
  Map<String, dynamic>? _verification;
  Map<String, dynamic>? _merkleProof;

  @override
  void initState() {
    super.initState();
    _refresh();
    _connectSocket();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _verifyController.dispose();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    try {
      final stream = await api.connectBlockchain();
      _socketSubscription = stream?.listen((_) => _refresh());
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Live updates unavailable; pull to refresh. $error');
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        api.portfolio(),
        api.history(),
        api.blocks(),
        api.audit(),
      ]);
      if (!mounted) return;
      setState(() {
        _portfolio = values[0] as Map<String, dynamic>;
        _transactions = values[1] as List<Map<String, dynamic>>;
        _blocks = values[2] as List<Map<String, dynamic>>;
        _audit = values[3] as List<Map<String, dynamic>>;
      });
      if (widget.user['role'] == 'admin') {
        final adminValues = await Future.wait<dynamic>([
          api.adminDashboard(),
          api.adminUsers(),
        ]);
        if (mounted) {
          setState(() {
            _adminStats = adminValues[0] as Map<String, dynamic>;
            _adminUsers = adminValues[1] as List<Map<String, dynamic>>;
          });
        }
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trade(String side, String amount) async {
    await api.trade(side, amount);
    await _refresh();
  }

  Future<void> _verify() async {
    try {
      final result = await api.verify(_verifyController.text.trim());
      if (mounted) setState(() => _verification = result);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _verification = {'valid': false, 'reason': error.toString()});
      }
    }
  }

  Future<void> _showMerkleProof(String transactionId) async {
    if (transactionId.isEmpty) {
      if (mounted) setState(() => _error = 'Enter a transaction ID first.');
      return;
    }
    try {
      final proof = await api.merkleProof(transactionId);
      if (mounted) setState(() => _merkleProof = proof);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _Overview(
        portfolio: _portfolio,
        transactions: _transactions,
        blocks: _blocks,
        loading: _loading,
        onNavigate: (index) => setState(() => _tab = index),
      ),
      _TradePage(portfolio: _portfolio, onTrade: _trade),
      _HistoryPage(transactions: _transactions),
      _ExplorerPage(blocks: _blocks, transactions: _transactions),
      _VerifyPage(
        transactions: _transactions,
        controller: _verifyController,
        result: _verification,
        onVerify: _verify,
        onMerkleProof: _showMerkleProof,
        proof: _merkleProof,
      ),
      _AuditPage(events: _audit),
      if (widget.user['role'] == 'admin')
        _AdminPage(stats: _adminStats, users: _adminUsers, events: _audit),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const _Brand(compact: true),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _showProfile, icon: const Icon(Icons.account_circle_outlined)),
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const _Notice(
            text: 'SIMULATION MODE · Virtual funds only · Not the Bitcoin network',
          ),
          if (_error != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              title: Text(_error!, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _error = null),
              ),
            ),
          Expanded(child: RefreshIndicator(onRefresh: _refresh, child: pages[_tab])),
        ],
      ),
      floatingActionButton: _tab == 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _tab = 1),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Trade BTC'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Trade'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'History'),
          NavigationDestination(icon: Icon(Icons.link), label: 'Explorer'),
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), label: 'Verify'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Audit'),
          if (widget.user['role'] == 'admin')
            const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }

  Future<void> _showProfile() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.user['email']}'),
            const SizedBox(height: 7),
            Text('Role: ${widget.user['role']}'),
            const SizedBox(height: 7),
            Text('Virtual USD: ${_money(_portfolio?['usd_balance'])}'),
            Text('BTC holdings: ${_number(_portfolio?['btc_balance'], 8).toStringAsFixed(8)} BTC'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.portfolio,
    required this.transactions,
    required this.blocks,
    required this.loading,
    required this.onNavigate,
  });

  final Map<String, dynamic>? portfolio;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> blocks;
  final bool loading;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Your virtual portfolio at a glance.',
            style: TextStyle(color: Colors.blueGrey.shade700)),
        const SizedBox(height: 17),
        _MetricCard(
          title: 'Portfolio value',
          value: _money(portfolio?['portfolio_value_usd']),
          subtitle: 'Virtual USD + BTC',
          icon: Icons.account_balance_wallet_outlined,
        ),
        _MetricCard(
          title: 'BTC holdings',
          value: '${_number(portfolio?['btc_balance'], 8)} BTC',
          subtitle: _money(
            _number(portfolio?['btc_balance'], 8) *
                _number(portfolio?['btc_price_usd']),
          ),
          icon: Icons.currency_bitcoin,
        ),
        _MetricCard(
          title: 'Available USD',
          value: _money(portfolio?['usd_balance']),
          subtitle: 'Virtual balance',
          icon: Icons.payments_outlined,
        ),
        _MetricCard(
          title: 'Blockchain blocks',
          value: '${blocks.length}',
          subtitle: '${transactions.length} simulated transactions',
          icon: Icons.link,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => onNavigate(1),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Trade BTC'),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Recent transactions'),
        if (transactions.isEmpty && loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ))
        else if (transactions.isEmpty)
          const _Empty(text: 'Your simulated trades will appear here.')
        else
          ...transactions.take(5).map((transaction) => _TransactionTile(transaction)),
      ],
    );
  }
}

class _TradePage extends StatefulWidget {
  const _TradePage({required this.portfolio, required this.onTrade});

  final Map<String, dynamic>? portfolio;
  final Future<void> Function(String side, String amount) onTrade;

  @override
  State<_TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<_TradePage> {
  final _amount = TextEditingController();
  String _side = 'buy';
  bool _busy = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _message = 'Enter a BTC quantity greater than zero.';
        _success = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onTrade(_side, amount.toStringAsFixed(8));
      setState(() {
        _message = '${_side.toUpperCase()} committed to the simulated ledger.';
        _success = true;
        _amount.clear();
      });
    } on Exception catch (error) {
      setState(() {
        _message = error.toString();
        _success = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _number(widget.portfolio?['btc_price_usd'], 65000);
    final balance = _side == 'buy'
        ? _money(widget.portfolio?['usd_balance'])
        : '${_number(widget.portfolio?['btc_balance'], 8).toStringAsFixed(8)} BTC';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Trade BTC', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text('Buy and sell with virtual funds only.',
            style: TextStyle(color: Colors.blueGrey.shade700)),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'buy', label: Text('Buy'), icon: Icon(Icons.south_west)),
            ButtonSegment(value: 'sell', label: Text('Sell'), icon: Icon(Icons.north_east)),
          ],
          selected: {_side},
          onSelectionChanged: (value) => setState(() {
            _side = value.first;
            _message = null;
          }),
        ),
        const SizedBox(height: 17),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('BTC quantity', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0.00000000', suffixText: 'BTC'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 17),
                _LabelValue(label: 'Demo BTC price', value: _money(price)),
                _LabelValue(
                  label: 'Estimated total',
                  value: _money((_number(_amount.text) * price)),
                ),
                _LabelValue(
                  label: _side == 'buy' ? 'Available virtual USD' : 'Available BTC',
                  value: balance,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Submitting…' : '${_side.toUpperCase()} BTC'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _success ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const _Notice(text: 'The demo price is configurable and is not a live exchange quote.'),
      ],
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.transactions});

  final List<Map<String, dynamic>> transactions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Transactions', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          const _Empty(text: 'No simulated transactions yet.')
        else
          ...transactions.map((transaction) => _TransactionTile(transaction)),
      ],
    );
  }
}

class _ExplorerPage extends StatefulWidget {
  const _ExplorerPage({required this.blocks, required this.transactions});

  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> transactions;

  @override
  State<_ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<_ExplorerPage> {
  final _searchController = TextEditingController();
  final _replacementController = TextEditingController();
  String? _selectedTransactionId;
  List<Map<String, dynamic>>? _simulation;
  String? _simulationError;
  bool _simulating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  Future<void> _simulate() async {
    final selectedId = _selectedTransactionId;
    final replacement = double.tryParse(_replacementController.text);
    if (selectedId == null || replacement == null || replacement <= 0) {
      setState(() {
        _simulationError = 'Choose a transaction and enter a positive BTC amount.';
      });
      return;
    }
    setState(() {
      _simulating = true;
      _simulationError = null;
    });
    try {
      final result = await api.simulateTampering(
        transactionId: selectedId,
        replacementQuantity: replacement.toStringAsFixed(8),
      );
      if (result['original_chain_unchanged'] != true) {
        throw const ApiException(
          'Ledger safety check failed. Simulation results were not displayed.',
        );
      }
      if (mounted) {
        setState(() {
          _simulation = (result['blocks'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _simulationError = error.toString());
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.trim().toLowerCase();
    final visibleBlocks = widget.blocks.where((block) {
      if (search.isEmpty) return true;
      final matchesBlock = '${block['index']}'.contains(search) ||
          '${block['block_hash']}'.toLowerCase().contains(search) ||
          '${block['previous_hash']}'.toLowerCase().contains(search);
      final matchesTransaction =
          (block['transactions'] as List<dynamic>? ?? const []).any((item) {
        final transaction = item as Map<String, dynamic>;
        return '${transaction['id']}'.toLowerCase().contains(search) ||
            '${transaction['transaction_hash']}'.toLowerCase().contains(search);
      });
      return matchesBlock || matchesTransaction;
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Blockchain explorer', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text('Simulated append-only educational ledger.',
            style: TextStyle(color: Colors.blueGrey.shade700)),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search block, transaction ID, or hash',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              onPressed: () => setState(_searchController.clear),
              icon: const Icon(Icons.close),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (visibleBlocks.isEmpty)
          const _Empty(text: 'No blocks available.')
        else
          ...visibleBlocks.reversed.map((block) {
            final index = block['index'];
            Map<String, dynamic>? simulationBlock;
            for (final item in _simulation ?? const <Map<String, dynamic>>[]) {
              if (item['index'] == index) {
                simulationBlock = item;
                break;
              }
            }
            final tampered = simulationBlock?['tampered'] == true;
            final valid = simulationBlock?['valid'] as bool? ??
                (block['valid'] == true);
            return Card(
              color: tampered
                  ? const Color(0xFFFFF0F1)
                  : _surface,
              child: ExpansionTile(
                leading: Icon(
                  valid ? Icons.verified_outlined : Icons.warning_amber_rounded,
                  color: valid ? Colors.greenAccent : Colors.redAccent,
                ),
                title: Text('Block #$index${tampered ? ' · SIMULATED TAMPER' : ''}'),
                subtitle: Text('${block['transaction_count']} transactions'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  _HashField(
                    label: tampered ? 'Simulated block hash' : 'Block hash',
                    value:
                        '${simulationBlock?['block_hash'] ?? block['block_hash']}',
                  ),
                  if (tampered)
                    _HashField(
                      label: 'Simulated Merkle root',
                      value:
                          '${simulationBlock?['merkle_root'] ?? block['merkle_root']}',
                    ),
                  _HashField(
                    label: 'Previous hash',
                    value:
                        '${simulationBlock?['previous_hash'] ?? block['previous_hash']}',
                  ),
                  _HashField(label: 'Timestamp', value: '${block['timestamp']}'),
                  ...(block['transactions'] as List<dynamic>? ?? const [])
                      .map((item) {
                    final transaction = item as Map<String, dynamic>;
                    return _HashField(
                      label:
                          '${transaction['transaction_type']} · ${transaction['id']}',
                      value: '${transaction['transaction_hash']}',
                    );
                  }),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.science_outlined, color: _cyan),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Tampering sandbox',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _FeatureChip(icon: Icons.lock_outline, label: 'COPY ONLY'),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Explore how a changed transaction breaks the chain. Your committed ledger is never edited.',
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedTransactionId,
                  decoration: const InputDecoration(labelText: 'Transaction'),
                  items: widget.transactions
                      .map(
                        (transaction) => DropdownMenuItem(
                          value: '${transaction['id']}',
                          child: Text(
                            '${transaction['transaction_type']} · ${transaction['btc_quantity']} BTC',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _simulating
                      ? null
                      : (value) => setState(() {
                            _selectedTransactionId = value;
                            _simulation = null;
                          }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _replacementController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Replacement BTC quantity',
                    hintText: '0.50000000',
                    suffixText: 'BTC',
                  ),
                ),
                if (_simulationError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _simulationError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                if (_simulation != null) ...[
                  const SizedBox(height: 12),
                  const _Notice(
                    text:
                        'Tampering detected in the temporary copy. Your committed ledger is unchanged.',
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _simulating || widget.transactions.isEmpty
                            ? null
                            : _simulate,
                        icon: _simulating
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_simulating ? 'Simulating…' : 'Simulate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _simulating
                          ? null
                          : () => setState(() {
                                _simulation = null;
                                _simulationError = null;
                                _replacementController.clear();
                              }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifyPage extends StatelessWidget {
  const _VerifyPage({
    required this.transactions,
    required this.controller,
    required this.result,
    required this.onVerify,
    required this.onMerkleProof,
    required this.proof,
  });

  final List<Map<String, dynamic>> transactions;
  final TextEditingController controller;
  final Map<String, dynamic>? result;
  final VoidCallback onVerify;
  final Future<void> Function(String transactionId) onMerkleProof;
  final Map<String, dynamic>? proof;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Verify transaction', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Checks transaction inclusion and blockchain integrity.',
            style: TextStyle(color: Colors.blueGrey.shade700)),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Transaction ID or transaction hash'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onVerify,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Verify'),
        ),
        if (transactions.isNotEmpty) ...[
          const SizedBox(height: 14),
          const _SectionTitle(title: 'Recent IDs'),
          ...transactions.take(5).map((tx) {
            final id = '${tx['id']}';
            return ListTile(
              dense: true,
              title: Text(id, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.north_west, size: 16),
              onTap: () => controller.text = id,
            );
          }),
        ],
        if (result != null)
          Card(
            child: ListTile(
              leading: Icon(
                result!['valid'] == true ? Icons.check_circle : Icons.cancel,
                color: result!['valid'] == true ? Colors.greenAccent : Colors.redAccent,
              ),
              title: Text(result!['valid'] == true
                  ? 'VALID TRANSACTION'
                  : 'INVALID TRANSACTION'),
              subtitle: Text('${result!['reason']}'),
            ),
          ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: () => onMerkleProof(controller.text.trim()),
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('Show Merkle inclusion proof'),
        ),
        if (proof != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merkle proof · block #${proof!['block_index']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _HashField(
                    label: 'Merkle root',
                    value: '${proof!['merkle_root']}',
                  ),
                  _HashField(
                    label: 'Transaction hash',
                    value: '${proof!['transaction_hash']}',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (proof!['valid'] == true)
                        ? 'Inclusion proof verified'
                        : 'Inclusion proof is invalid',
                    style: TextStyle(
                      color: proof!['valid'] == true
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  ...(proof!['proof'] as List<dynamic>).map((node) {
                    final sibling = node as Map<String, dynamic>;
                    return _HashField(
                      label: '${sibling['side']} sibling',
                      value: '${sibling['hash']}',
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuditPage extends StatelessWidget {
  const _AuditPage({required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Audit history', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const _Empty(text: 'No audit events are available.')
        else
          ...events.map((event) => Card(
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined, color: _cyan),
                  title: Text('${event['action']}'),
                  subtitle: Text('${event['timestamp']}'),
                ),
              )),
      ],
    );
  }
}

class _AdminPage extends StatelessWidget {
  const _AdminPage({
    required this.stats,
    required this.users,
    required this.events,
  });

  final Map<String, dynamic>? stats;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Admin dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text('Monitor the simulator; committed blocks are append-only.',
            style: TextStyle(color: Colors.blueGrey.shade700)),
        const SizedBox(height: 13),
        _MetricCard(
          title: 'Registered users',
          value: '${stats?['registered_users'] ?? 0}',
          subtitle: 'Accounts',
          icon: Icons.people_outline,
        ),
        _MetricCard(
          title: 'Transactions',
          value: '${stats?['transactions'] ?? 0}',
          subtitle: '${stats?['btc_traded'] ?? 0} BTC traded',
          icon: Icons.swap_horiz,
        ),
        _MetricCard(
          title: 'Blocks',
          value: '${stats?['blocks'] ?? 0}',
          subtitle: 'Append-only ledger',
          icon: Icons.link,
        ),
        _MetricCard(
          title: 'Valid blocks',
          value: '${stats?['valid_blocks'] ?? 0}',
          subtitle: 'Current integrity check',
          icon: Icons.verified_user_outlined,
        ),
        _MetricCard(
          title: 'Invalid verification attempts',
          value: '${stats?['invalid_verification_attempts'] ?? 0}',
          subtitle: '${stats?['audit_events'] ?? 0} audit events',
          icon: Icons.shield_outlined,
        ),
        const _SectionTitle(title: 'Users'),
        ...users.map(
          (user) => Card(
            child: ListTile(
              title: Text('${user['email']}'),
              subtitle: Text('${user['id']}'),
              trailing: Text('${user['role']}'),
            ),
          ),
        ),
        const _SectionTitle(title: 'Recent audit events'),
        ...events.take(5).map(
          (event) => Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined, color: _cyan),
              title: Text('${event['action']}'),
              subtitle: Text('${event['timestamp']}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context) {
    final buying = transaction['transaction_type'] == 'BUY';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: buying
              ? const Color(0xFFE8F7F1)
              : const Color(0xFFFFF0F1),
          child: Icon(
            buying ? Icons.south_west : Icons.north_east,
            color: buying ? Colors.greenAccent : Colors.redAccent,
            size: 18,
          ),
        ),
        title: Text('${transaction['transaction_type']} · ${transaction['btc_quantity']} BTC'),
        subtitle: Text('Block #${transaction['block_index']} · ${transaction['id']}'),
        trailing: Text(
          _money(transaction['total_usd']),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon, color: _cyan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_cyan, Color(0xFF3977F6)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('B', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 9),
        const Text('BitTrade', style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F1),
        border: Border.all(color: const Color(0xFFC9E9DC)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: Color(0xFF168A68)),
          SizedBox(width: 5),
          Text(
            'VIRTUAL ONLY',
            style: TextStyle(
              color: Color(0xFF167653),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FC),
        border: Border.all(color: const Color(0xFFD9E7F1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF087FA5)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF53657B)),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FA),
        border: Border.all(color: const Color(0xFFD2E5F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF405A70))),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 5),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _HashField extends StatelessWidget {
  const _HashField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 10)),
            const SizedBox(height: 3),
            SelectableText(value, style: const TextStyle(fontSize: 10, color: _cyan)),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(text, style: TextStyle(color: Colors.blueGrey.shade700)),
        ),
      );
}

String _money(dynamic value) {
  final parsed = _number(value);
  return '\$${parsed.toStringAsFixed(2)}';
}

double _number(dynamic value, [double fallback = 0]) =>
    value == null ? fallback : double.tryParse(value.toString()) ?? fallback;
