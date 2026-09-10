/// Declares a stable execution priority. Smaller values run first.
abstract interface class Ordered {
  int get order;
}
