module Test.Main
  ( main
  ) where

import Control.Monad.Aff (launchAff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Exception (EXCEPTION, error)
import Control.Monad.Error.Class (throwError, try)

import Data.DateTime (DateTime)

import Data.Either(fromRight)
import Data.Formatter.DateTime (unformatDateTime)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)

import Database.PostgreSQL (POSTGRESQL, PoolConfiguration, Query(..), Row0(..), Row1(..), Row3(..), execute, newPool, query, scalar, withConnection, withTransaction, toSQLValue, fromSQLValue)

import Partial.Unsafe (unsafePartial)

import Prelude

import Test.Assert (ASSERT, assert)

main :: ∀ eff. Eff (assert :: ASSERT, exception :: EXCEPTION, postgreSQL :: POSTGRESQL | eff) Unit
main = do
  void $ launchAff do
    pool <- newPool config
    withConnection pool \conn -> do
      execute conn (Query """
        CREATE TEMPORARY TABLE foods (
          name text NOT NULL,
          delicious boolean NOT NULL,
          last_eaten timestamp NOT NULL,
          PRIMARY KEY (name)
        )
      """) Row0

      _ <- traverse (insert conn) [
        (Row3 "pork" true iso8601),
        (Row3 "sauerkraut" false iso8601),
        (Row3 "rookworst" true iso8601)
      ]

      names <- query conn (Query """
        SELECT name
        FROM foods
        WHERE delicious
        ORDER BY name ASC
      """) Row0
      liftEff <<< assert $ names == [Row1 "pork", Row1 "rookworst"]

      last_eatens <- query conn (Query """
         SELECT last_eaten
         FROM foods
         where delicious
         ORDER BY name ASC
        """) Row0
      liftEff <<< assert $ last_eatens == [Row1 iso8601, Row1 iso8601]

      testTransactionCommit conn
      testTransactionRollback conn

      pure unit
  where

  iso8601 :: DateTime
  iso8601 = unsafePartial $ fromRight $ unformatDateTime "YYYY-MM-DD hh:mm:ss" "2014-02-20 11:11:11"

  insert conn = execute conn (Query """
      INSERT INTO foods (name, delicious, last_eaten)
      VALUES ($1, $2, $3)
    """)

  deleteAll conn =
    execute conn (Query """
      DELETE FROM foods
    """) Row0

  testTransactionCommit conn = do
    deleteAll conn
    withTransaction conn do
      insert conn (Row3 "pork" true iso8601)
      testCount conn 1
    testCount conn 1

  testTransactionRollback conn = do
    deleteAll conn
    _ <- try $ withTransaction conn do
      insert conn (Row3 "pork" true iso8601)
      testCount conn 1
      throwError $ error "fail"
    testCount conn 0

  testCount conn n = do
    count <- scalar conn (Query """
      SELECT count(*) = $1
      FROM foods
    """) (Row1 n)
    liftEff <<< assert $ count == Just true

config :: PoolConfiguration
config =
  { user: "postgres"
  , password: "lol123"
  , host: "127.0.0.1"
  , port: 5432
  , database: "purspg"
  , max: 10
  , idleTimeoutMillis: 1000
  }
