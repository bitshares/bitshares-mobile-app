package com.google.zxing.utils;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.provider.MediaStore;
import android.util.Log;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.ChecksumException;
import com.google.zxing.DecodeHintType;
import com.google.zxing.FormatException;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.NotFoundException;
import com.google.zxing.PlanarYUVLuminanceSource;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.Result;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.multi.qrcode.QRCodeMultiReader;
import com.google.zxing.qrcode.QRCodeReader;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.Hashtable;

/**
 * Created by lockyluo on 2017/8/19.
 */

public class PicDecode {
    private static final String tag = "PicDecode";
    private static byte[] yuvs;

    public static Result scanImage(Activity context, Uri uri) {
        if (uri == null) {
            Log.e(tag, "null");
            return null;
        }
        Bitmap scanBitmap;
        Hashtable<DecodeHintType, Object> hints = new Hashtable();
        hints.put(DecodeHintType.CHARACTER_SET, "UTF-8"); // 设置二维码内容的编码
        hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
        hints.put(DecodeHintType.POSSIBLE_FORMATS, BarcodeFormat.QR_CODE);

        try {
            scanBitmap = getBitmapFormUri(context, uri, 0);
        } catch (Exception e) {
            e.printStackTrace();
            Log.e(tag, e.getMessage());
            return null;
        }
        int width = scanBitmap.getWidth();
        int height = scanBitmap.getHeight();
        int[] data = new int[width * height];
        scanBitmap.getPixels(data, 0, width, 0, 0, width, height);
        RGBLuminanceSource source1 = new RGBLuminanceSource(width, height, data);
        BinaryBitmap binaryBitmap1 = new BinaryBitmap(new HybridBinarizer(source1));

        QRCodeReader reader = new QRCodeReader();
        Result result = null;

        try {
            result = reader.decode(binaryBitmap1, hints);
            Log.e(tag, result.getText());
        } catch (NotFoundException e) {
            Log.e(tag, "NotFoundException");
            result = backupDecode(context, uri, result);
            e.printStackTrace();
        } catch (ChecksumException e) {
            Log.e(tag, "ChecksumException");
            result = backupDecode(context, uri, result);
            e.printStackTrace();
        } catch (FormatException e) {
            Log.e(tag, "FormatException");
            result = backupDecode(context, uri, result);
            e.printStackTrace();
        } catch (Exception e) {
            Log.e(tag, e.getMessage());
            result = backupDecode(context, uri, result);
            e.printStackTrace();
        }
//        scanBitmap.recycle();
        return result;
    }

    public static Result backupDecode(Activity context, Uri uri, Result result) {

        try {
            result = null;
            //备用方案
            Log.e(tag, "备用方案");
            Bitmap scanBitmap;
            Hashtable<DecodeHintType, Object> hints = new Hashtable();
            hints.put(DecodeHintType.CHARACTER_SET, "UTF-8"); // 设置二维码内容的编码
            hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
            //复杂模式，开启PURE_BARCODE模式
//            hints.put(DecodeHintType.PURE_BARCODE, Boolean.FALSE);
//            hints.put(DecodeHintType.POSSIBLE_FORMATS, BarcodeFormat.QR_CODE);
            try {
                scanBitmap = getBitmapFormUri(context, uri, 1);
            } catch (Exception e) {
                e.printStackTrace();
                Log.e(tag, e.getMessage());
                return null;
            }
            int width = scanBitmap.getWidth();
            int height = scanBitmap.getHeight();
            byte[] dataYUV = getYUV420sp(width, height, scanBitmap);
            PlanarYUVLuminanceSource source2 = new PlanarYUVLuminanceSource(dataYUV,
                    width,
                    height,
                    0, 0,
                    width,
                    height,
                    false);
            BinaryBitmap binaryBitmap2 = new BinaryBitmap(new HybridBinarizer(source2));
            MultiFormatReader reader = new MultiFormatReader();
//            scanBitmap.recycle();
            result = reader.decode(binaryBitmap2, hints);
            Log.e(tag, result.getText());
        } catch (NotFoundException e1) {
            Log.e(tag, "NotFoundException");
            e1.printStackTrace();
        } catch (Exception e1) {
            Log.e(tag, "Exception");
            e1.printStackTrace();
        }
        return result;
    }


    private static void encodeYUV420SP(byte[] yuv420sp, int[] argb, int width,
                                       int height) {
        // 帧图片的像素大小
        final int frameSize = width * height;
        // ---YUV数据---
        int Y, U, V;
        // Y的index从0开始
        int yIndex = 0;
        // UV的index从frameSize开始
        int uvIndex = frameSize;

        // ---颜色数据---
//      int a, R, G, B;
        int R, G, B;
        //
        int argbIndex = 0;
        //

        // ---循环所有像素点，RGB转YUV---
        for (int j = 0; j < height; j++) {
            for (int i = 0; i < width; i++) {

                // a is not used obviously
//              a = (argb[argbIndex] & 0xff000000) >> 24;
                R = (argb[argbIndex] & 0xff0000) >> 16;
                G = (argb[argbIndex] & 0xff00) >> 8;
                B = (argb[argbIndex] & 0xff);
                //
                argbIndex++;

                // well known RGB to YUV algorithm
                Y = ((66 * R + 129 * G + 25 * B + 128) >> 8) + 16;
                U = ((-38 * R - 74 * G + 112 * B + 128) >> 8) + 128;
                V = ((112 * R - 94 * G - 18 * B + 128) >> 8) + 128;

                //
                Y = Math.max(0, Math.min(Y, 255));
                U = Math.max(0, Math.min(U, 255));
                V = Math.max(0, Math.min(V, 255));


                yuv420sp[yIndex++] = (byte) Y;

            }
        }
    }

    /**
     * 通过uri获取图片并进行压缩
     *
     * @param uri
     */
    public static Bitmap getBitmapFormUri(Activity ac, Uri uri, int doCompress) throws IOException {
        int maxMemory = (int) (Runtime.getRuntime().maxMemory() / 1024);
        Log.d(tag, "Max memory is " + maxMemory + "KB");
        String path = getRealFilePathFromUri(ac, uri);

        Bitmap bitmap = null;
        int degree = PhotoBitmapUtils.readPictureDegree(path);
        Log.d(tag, "degree " + degree);
        int w = 512;
        int h = 512;

        try {
            bitmap = decodeSampledBitmapFromFile(path, w, h);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
        bitmap = PhotoBitmapUtils.rotaingImageView(degree, bitmap);


        if (doCompress == 0) {
            return bitmap;
        } else {
            return compressImage(bitmap);//再进行质量压缩
        }
    }

    /**
     * 质量压缩方法
     *
     * @param image
     * @return
     */
    public static Bitmap compressImage(Bitmap image) {

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        image.compress(Bitmap.CompressFormat.JPEG, 100, baos);//质量压缩方法，这里100表示不压缩，把压缩后的数据存放到baos中
        int options = 100;
        while (baos.toByteArray().length / 1024 > 200) {  //循环判断如果压缩后图片是否大于?kb,大于继续压缩
            Log.d(tag, "compressImage " + options);
            baos.reset();//重置baos即清空baos
            //第一个参数 ：图片格式 ，第二个参数： 图片质量，100为最高，0为最差  ，第三个参数：保存压缩后的数据的流
            image.compress(Bitmap.CompressFormat.JPEG, options, baos);//这里压缩options%，把压缩后的数据存放到baos中
            options -= 10;//每次都减少10
        }
        ByteArrayInputStream isBm = new ByteArrayInputStream(baos.toByteArray());//把压缩后的数据baos存放到ByteArrayInputStream中
        Bitmap bitmap = BitmapFactory.decodeStream(isBm, null, null);//把ByteArrayInputStream数据生成图片
        return bitmap;
    }

    /**
     * Gets the content:// URI from the given corresponding path to a file
     *
     * @param context
     * @param imageFile
     * @return content Uri
     */
    public static Uri getImageContentUri(Context context, java.io.File imageFile) {
        String filePath = imageFile.getAbsolutePath();
        Cursor cursor = context.getContentResolver().query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                new String[]{MediaStore.Images.Media._ID}, MediaStore.Images.Media.DATA + "=? ",
                new String[]{filePath}, null);
        if (cursor != null && cursor.moveToFirst()) {
            int id = cursor.getInt(cursor.getColumnIndex(MediaStore.MediaColumns._ID));
            Uri baseUri = Uri.parse("content://media/external/images/media");
            return Uri.withAppendedPath(baseUri, "" + id);
        } else {
            if (imageFile.exists()) {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Images.Media.DATA, filePath);
                return context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            } else {
                return null;
            }
        }
    }

    /**
     * Try to return the absolute file path from the given Uri
     *
     * @param context
     * @param uri
     * @return the file path or null
     */
    public static String getRealFilePathFromUri(final Context context, final Uri uri) {
        if (null == uri) return null;
        final String scheme = uri.getScheme();
        String data = null;
        if (scheme == null)
            data = uri.getPath();
        else if (ContentResolver.SCHEME_FILE.equals(scheme)) {
            data = uri.getPath();
        } else if (ContentResolver.SCHEME_CONTENT.equals(scheme)) {
            Cursor cursor = context.getContentResolver().query(uri, new String[]{MediaStore.Images.ImageColumns.DATA}, null, null, null);
            if (null != cursor) {
                if (cursor.moveToFirst()) {
                    int index = cursor.getColumnIndex(MediaStore.Images.ImageColumns.DATA);
                    if (index > -1) {
                        data = cursor.getString(index);
                    }
                }
                cursor.close();
            }
        }
        return data;
    }

    /**
     * 根据Bitmap的ARGB值生成YUV420SP数据。
     *
     * @param inputWidth  image width
     * @param inputHeight image height
     * @param scaled      bmp
     * @return YUV420SP数组
     */
    public static byte[] getYUV420sp(int inputWidth, int inputHeight, Bitmap scaled) {
        int[] argb = new int[inputWidth * inputHeight];
        scaled.getPixels(argb, 0, inputWidth, 0, 0, inputWidth, inputHeight);
        /**
         * 需要转换成偶数的像素点，否则编码YUV420的时候有可能导致分配的空间大小不够而溢出。
         */
        int requiredWidth = inputWidth % 2 == 0 ? inputWidth : inputWidth + 1;
        int requiredHeight = inputHeight % 2 == 0 ? inputHeight : inputHeight + 1;
        int byteLength = requiredWidth * requiredHeight * 3 / 2;
        if (yuvs == null || yuvs.length < byteLength) {
            yuvs = new byte[byteLength];
        } else {
            Arrays.fill(yuvs, (byte) 0);
        }
        encodeYUV420SP(yuvs, argb, inputWidth, inputHeight);
//        scaled.recycle();
        return yuvs;
    }

    /**
     * 根据给定的宽度和高度动态计算图片压缩比率
     *
     * @param options   Bitmap配置文件
     * @param reqWidth  需要压缩到的宽度
     * @param reqHeight 需要压缩到的高度
     * @return 压缩比
     */
    public static int calculateInSampleSize(BitmapFactory.Options options, int reqWidth, int reqHeight) {
        // Raw height and width of image
        final int height = options.outHeight;
        final int width = options.outWidth;
        int inSampleSize = 1;

        if (height > reqHeight || width > reqWidth) {

            final int halfHeight = height / 2;
            final int halfWidth = width / 2;

            // Calculate the largest inSampleSize value that is a power of 2 and keeps both
            // height and width larger than the requested height and width.
            while ((halfHeight / inSampleSize) > reqHeight && (halfWidth / inSampleSize) > reqWidth) {
                inSampleSize *= 2;
            }

        }

        return inSampleSize;
    }

    /**
     * 将图片根据压缩比压缩成固定宽高的Bitmap，实际解析的图片大小可能和#reqWidth、#reqHeight不一样。
     *
     * @param imgPath   图片地址
     * @param reqWidth  需要压缩到的宽度
     * @param reqHeight 需要压缩到的高度
     * @return Bitmap
     */
    public static Bitmap decodeSampledBitmapFromFile(String imgPath, int reqWidth, int reqHeight) {

        // First decode with inJustDecodeBounds=true to check dimensions
        final BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(imgPath, options);

        // Calculate inSampleSize
        options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight);
        Log.d(tag, "----------------------------------------");
        Log.d(tag, "decodeSampledBitmapFromFile inSampleSize:" + options.inSampleSize);
        // Decode bitmap with inSampleSize set
        options.inJustDecodeBounds = false;
        return BitmapFactory.decodeFile(imgPath, options);
    }


}
