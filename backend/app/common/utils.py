from pymongo.errors import OperationFailure

# pymongo OperationFailure code 20 (IllegalOperation) covers several cases;
# only treat it as "transactions unsupported" when the message confirms it -
# i.e. a standalone mongod instead of a replica set / mongos. Shared by
# every "create an auth account + a business profile atomically" flow
# (drivers, institutions, ...) so they fall back to manual rollback the
# same way against this project's local standalone MongoDB.
_TRANSACTIONS_UNSUPPORTED_CODE = 20


def is_transactions_unsupported(error: OperationFailure) -> bool:
    return error.code == _TRANSACTIONS_UNSUPPORTED_CODE and (
        "replica set" in str(error).lower()
    )
