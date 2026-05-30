// MIGRATE LATER : remplacer par sg_core/Result<T,E> dès qu'il est pure-Dart.
// API maintenue strictement compatible avec sg_core pour migration zero-cost.
// Code identique à nono-cook/nc_core ; refactor en sg_core_dart prévu v0.3.

import 'package:meta/meta.dart';

@immutable
sealed class Result<T, E> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  });

  bool get isSuccess;
  bool get isFailure => !isSuccess;
  T? get valueOrNull;
  E? get errorOrNull;
  Result<R, E> map<R>(R Function(T value) transform);
  Result<T, F> mapError<F>(F Function(E error) transform);
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform);
  T getOrElse(T Function(E error) onFailure);

  static Result<T, E> success<T, E>(T value) => Success<T, E>(value);
  static Result<T, E> failure<T, E>(E error) => Failure<T, E>(error);
}

@immutable
final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  bool get isSuccess => true;

  @override
  T? get valueOrNull => value;

  @override
  E? get errorOrNull => null;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) => success(value);

  @override
  Result<R, E> map<R>(R Function(T value) transform) =>
      Success<R, E>(transform(value));

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) =>
      Success<T, F>(value);

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) =>
      transform(value);

  @override
  T getOrElse(T Function(E error) onFailure) => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Success<T, E> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

@immutable
final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  bool get isSuccess => false;

  @override
  T? get valueOrNull => null;

  @override
  E? get errorOrNull => error;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) => failure(error);

  @override
  Result<R, E> map<R>(R Function(T value) transform) => Failure<R, E>(error);

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) =>
      Failure<T, F>(transform(error));

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) =>
      Failure<R, E>(error);

  @override
  T getOrElse(T Function(E error) onFailure) => onFailure(error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T, E> && other.error == error);

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}
