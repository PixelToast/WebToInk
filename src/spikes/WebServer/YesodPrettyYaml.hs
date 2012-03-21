{-# LANGUAGE TypeFamilies, QuasiQuotes, TemplateHaskell, MultiParamTypeClasses, OverloadedStrings #-}
import Yesod
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as L

data PY = PY
-- type Handler = GHandler PY PY

mkYesod "PY" [$parseRoutes|
/ Homepage GET POST
|]
instance Yesod PY where approot _ = ""
-- template :: Maybe (Hamlet url) -> Hamlet url
template myaml = [$hamlet|

!!!
<html>
    <head>
        <meta charset="utf-8">
        <title>Pretty YAML>     <body>
        <form method="post" action="" enctype="multipart/form-data" .>
            \File name:
            <input type="file" name="yaml">
            <input type="submit">
        $maybe yaml <- myaml
            <div>^{yaml}
|]
getHomepage :: Handler RepHtml
getHomepage = hamletToRepHtml $ template Nothing
postHomepage :: Handler RepHtml
postHomepage = do
    (_, files) <- runRequestBody
    fi <- case lookup "yaml" files of
            Nothing -> invalidArgs ["yaml: Missing input"]
            Just x -> return x
    so <- liftIO $ decode $ B.concat $ L.toChunks $ fileContent fi
    hamletToRepHtml $ template $ Just $ objToHamlet so
objToHamlet :: StringObject -> Hamlet url
objToHamlet (Scalar s) = [$hamlet|#{s}|]
objToHamlet (Sequence list) = [$hamlet|
<ul
    $forall o <- list
        <li>^{objToHamlet o}
|]
objToHamlet (Mapping pairs) = [$hamlet|
<dl
    $forall pair <- pairs
        <dt>#{fst pair}
        <dd>^{objToHamlet $ snd pair}
|]
main :: IO ()
main = warpDebug 3000 PY
