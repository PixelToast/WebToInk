module Converter where

import Converter.HtmlPages(getHtmlPages, filterOutSections, isTopLink, containsBaseHref, getRootUrl)
import Converter.Images(getImages)
import Converter.Download(downloadPage, savePage, downloadAndSaveImages, getSrcFilePath)
import Converter.OpfGeneration(generateOpf)
import Converter.TocGeneration(generateToc)
import Converter.CommandLineParser(Args(..), legend, parseArgs)
import Converter.Types
import Converter.Constants

import System.Directory(createDirectoryIfMissing, setCurrentDirectory)
import Control.Monad(forM)
import Data.String.Utils(replace)
import Data.Maybe(fromJust)
import Data.List(isPrefixOf, nub)
import System.Environment(getArgs)

import Test.HUnit

main = do   
    argsList <- getArgs

    -- TODO: check args to be valid
    let args = parseArgs argsList

    prepareKindleGeneration 
        (fromJust $ title args)
        (fromJust $ author args) 
        (language args) 
        (fromJust $ tocUrl args) 
        (folder args)

prepareKindleGeneration :: String -> String -> String -> Url -> FilePath -> IO ()
prepareKindleGeneration title creator language tocUrl folder = do

    pagesDic <- getHtmlPages tocUrl

    let topPagesDic = filter (isTopLink . fst) pagesDic
    let topPages = map fst topPagesDic

    putStrLn $ prettifyList topPagesDic
    
    createKindleStructure topPagesDic topPages

    where
        targetFolder = folder ++ "/" ++ title

        createKindleStructure topPagesDic topPages = do

            createDirectoryIfMissing False targetFolder  
            setCurrentDirectory targetFolder

            referencedImages <- downloadPages tocUrl topPagesDic    

            putStrLn $ prettifyList topPages 
            let opfString = generateOpf topPages referencedImages title language creator 
            writeFile "book.opf" opfString

            let tocString = generateToc topPages title language creator
            writeFile "toc.ncx" tocString

            setCurrentDirectory ".."

downloadPages :: Url -> [(FilePath, Url)] -> IO [Url]
downloadPages tocUrl topPagesDic = do
    let rootUrl = getRootUrl tocUrl

    allImageUrls <- mapM (\(fileName, pageUrl) -> do
        putStrLn $ "Downloading: " ++ fileName
        pageContents <- downloadPage pageUrl

        let imageUrls = (filter (not . ("https:" `isPrefixOf`)) . getImages) pageContents

        putStrLn $ prettifyList imageUrls 
        downloadAndSaveImages rootUrl pageUrl imageUrls

        let localizedPageContents = localizePageContents imageUrls pageContents

        savePage fileName localizedPageContents

        return imageUrls
        ) topPagesDic 
    return $ (map (getSrcFilePath "") . nub . concat) allImageUrls

localizePageContents :: [Url] -> PageContents -> PageContents
localizePageContents imageUrls pageContents = 
    removeBaseHref .  localizeSrcUrls ("../" ++ imagesFolder) imageUrls $ pageContents 

localizeSrcUrls :: FilePath -> [Url] -> PageContents  -> PageContents
localizeSrcUrls targetFolder srcUrls pageContents =
    foldr (\srcUrl contents -> 
        replace ("src=\"" ++ srcUrl) ("src=\"" ++ getSrcFilePath targetFolder srcUrl) contents) 
        pageContents srcUrls

removeBaseHref :: PageContents -> PageContents
removeBaseHref = unlines . filter (not . containsBaseHref) . lines
    
prettifyList :: Show a => [a] -> String
prettifyList = foldr ((++) . (++) "\n" . show) ""

-- ===================
-- Tests
-- ===================

localizeSrcUrlsTests =
    [ assertEqual "localizing src urls"
        (localizeSrcUrls filePath imageUrls pageContents) localizedPageContents 
    ]
    where
        filePath = "../images"
        pageContents = 
            "<body>" ++
                "<img src=\"/support/figs/rss.png\"/>" ++
                "<span>some span</span>" ++
                "<img src=\"/support/figs/ball.png\"/>" ++
            "</body>"
        imageUrls = [ "/support/figs/rss.png", "/support/figs/ball.png" ]
        localizedPageContents =
            "<body>" ++
                "<img src=\"" ++ filePath ++ "/rss.png\"/>" ++
                "<span>some span</span>" ++
                "<img src=\"" ++ filePath ++ "/ball.png\"/>" ++
            "</body>"

removeBaseHrefTests = 
    [ assertEqual "removing base href"
        processedPageContents (removeBaseHref pageContents)
    ]
    where 
        pageContents =
            "<head>\n" ++
                "<base href=\"http://learnyouahaskell.com/\">\n" ++ 
            "</head>\n"
        processedPageContents = 
            "<head>\n" ++
            "</head>\n"
    
tests = TestList $ map TestCase $
    localizeSrcUrlsTests ++
    removeBaseHrefTests 

runTests = runTestTT tests

