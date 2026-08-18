import '../errors/failure.dart';

sealed class ViewState<T> {
  const ViewState();
}

class Loading<T> extends ViewState<T> {
  const Loading();
}

class Loaded<T> extends ViewState<T> {
  const Loaded(this.data);
  final T data;
}

class Failed<T> extends ViewState<T> {
  const Failed(this.failure);
  final Failure failure;
}
