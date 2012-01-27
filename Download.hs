module Download
    ( downloadAndSaveImages
    , downloadPage
    , savePage
    , getSrcFilePath
    ) where

import Types
import Constants(pagesFolder, imagesFolder)
import Utils(openUrl)
import System.Directory(createDirectoryIfMissing, setCurrentDirectory, doesFileExist)
import System.IO(hPutStr, withFile, IOMode(..))
import System.FilePath(takeFileName)
import Data.List(isPrefixOf)

import Network.HTTP.Conduit
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString as B
import qualified Data.ByteString.UTF8 as U
import Control.Exception as X

import Test.HUnit

downloadAndSaveImages rootUrl imageUrls = do
    createDirectoryIfMissing False imagesFolder
    mapM (downloadAndSaveImage imagesFolder rootUrl) imageUrls

downloadPage ::  Url -> IO String
downloadPage url = do
    pageContents <- openUrl url
    return pageContents

savePage ::  FilePath -> String -> IO ()
savePage fileName pageContents = do
    createDirectoryIfMissing False pagesFolder
    write (pagesFolder ++ "/" ++ fileName) pageContents 
    where write fileName pageContents = do 
            withFile fileName WriteMode (\handle -> hPutStr handle pageContents)

downloadAndSaveImage :: FilePath -> Url -> Url -> IO ()
downloadAndSaveImage targetFolder rootUrl url =
    -- hack to prevent image not found errors until we figure out errorhandling
    if (head url) == 'f' || (head url) == 'i'
        then return undefined
        else do
            let fullUrl = resolveUrl rootUrl url
            let fullPath = getSrcFilePath targetFolder url
            imageWasDownloadedBefore <- doesFileExist fullPath 
            if imageWasDownloadedBefore 
                then return undefined
                else simpleHttp fullUrl >>= L.writeFile fullPath


resolveUrl :: Url -> Url -> Url
resolveUrl rootUrl url
        | "http://" `isPrefixOf` url = url
        | otherwise                  = rootUrl ++ "/" ++ url

getSrcFilePath :: FilePath -> Url -> FilePath
getSrcFilePath targetFolder url = targetFolder ++ "/" ++ (takeFileName url)

downloadString :: Url -> IO (Maybe String)
downloadString url = do
    result <- downloadByteString url
    case result of
        Nothing         -> return Nothing
        Just byteString -> return (Just "a")

downloadByteString :: Url -> IO (Maybe L.ByteString)
downloadByteString url = do
    byteString <- (simpleHttp url) `X.catch` statusCodeExceptionHandler
    case byteString of x | x == L.empty -> return Nothing 
                         | otherwise    -> return (Just byteString)
    where
        statusCodeExceptionHandler ::  HttpException -> IO L.ByteString
        statusCodeExceptionHandler (StatusCodeException status headers) = 
            putStrLn ("An error when trying to download: " ++ url)
            >> (putStrLn $ show status)
            >> (return L.empty)

-- ===================
-- Tests
-- ===================

resolveUrlTests = 
    [ assertEqual "resolving relative url appends it to root url"
        (resolveUrl root relativeUrl) (root ++ "/" ++ relativeUrl)
    , assertEqual "resolving absolute url returns it as is"
        (resolveUrl root absoluteUrl) (absoluteUrl) 
    ]
    where 
        root = "http://my.root.url"
        relativeUrl = "relative/to/root/some.png"
        absoluteUrl = "http://some.absolute.com"

getSrcFilePathTests = 
    [ assertEqual "getting file path for valid image url"
        (getSrcFilePath targetFolder imgUrl) (targetFolder ++ "/" ++ imgFileName)
    ]
    where
        targetFolder = "someFolder"
        imgFileName = "some.png"
        imgUrl = "/images/" ++ imgFileName
        
tests = TestList $ map TestCase $
    resolveUrlTests ++ 
    getSrcFilePathTests 

runTests = do
    runTestTT tests
