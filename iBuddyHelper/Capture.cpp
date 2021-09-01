#define WIN32_LEAN_AND_MEAN    
#pragma warning(disable:4190)

#include "BeefySysLib/Common.h"
#include "BeefySysLib/util/TLSingleton.h"
#include "BeefySysLib/img/JPEGData.h"

#include <windows.h>
#include <shlobj.h>
#include <shellapi.h>
#include <dxgi1_2.h>
#include <d3d11.h>
#include <memory>
#include <algorithm>
#include <string>

USING_NS_BF;

#pragma comment(lib, "D3D11.lib")

template <typename T>
class CComPtrCustom
{
public:

	CComPtrCustom(T* aPtrElement)
		:element(aPtrElement)
	{
	}

	CComPtrCustom()
		:element(nullptr)
	{
	}

	virtual ~CComPtrCustom()
	{
		Release();
	}

	T* Detach()
	{
		auto lOutPtr = element;

		element = nullptr;

		return lOutPtr;
	}

	T* detach()
	{
		return Detach();
	}

	void Release()
	{
		if (element == nullptr)
			return;

		auto k = element->Release();

		element = nullptr;
	}

	CComPtrCustom& operator = (T* pElement)
	{
		Release();

		if (pElement == nullptr)
			return *this;

		auto k = pElement->AddRef();

		element = pElement;

		return *this;
	}

	void Swap(CComPtrCustom& other)
	{
		T* pTemp = element;
		element = other.element;
		other.element = pTemp;
	}

	T* operator->()
	{
		return element;
	}

	operator T* ()
	{
		return element;
	}

	operator T* () const
	{
		return element;
	}


	T* get()
	{
		return element;
	}

	T* get() const
	{
		return element;
	}

	T** operator &()
	{
		return &element;
	}

	bool operator !()const
	{
		return element == nullptr;
	}

	operator bool()const
	{
		return element != nullptr;
	}

	bool operator == (const T* pElement)const
	{
		return element == pElement;
	}


	CComPtrCustom(const CComPtrCustom& aCComPtrCustom)
	{
		if (aCComPtrCustom.operator!())
		{
			element = nullptr;

			return;
		}

		element = aCComPtrCustom;

		auto h = element->AddRef();

		h++;
	}

	CComPtrCustom& operator = (const CComPtrCustom& aCComPtrCustom)
	{
		Release();

		element = aCComPtrCustom;

		auto k = element->AddRef();

		return *this;
	}

	_Check_return_ HRESULT CopyTo(T** ppT) throw()
	{
		if (ppT == NULL)
			return E_POINTER;

		*ppT = element;

		if (element)
			element->AddRef();

		return S_OK;
	}

	HRESULT CoCreateInstance(const CLSID aCLSID)
	{
		T* lPtrTemp;

		auto lresult = ::CoCreateInstance(aCLSID, NULL, CLSCTX_INPROC, IID_PPV_ARGS(&lPtrTemp));

		if (SUCCEEDED(lresult))
		{
			if (lPtrTemp != nullptr)
			{
				Release();

				element = lPtrTemp;
			}

		}

		return lresult;
	}

protected:

	T* element;
};


// Driver types supported
D3D_DRIVER_TYPE gDriverTypes[] =
{
	D3D_DRIVER_TYPE_HARDWARE
};
UINT gNumDriverTypes = ARRAYSIZE(gDriverTypes);

// Feature levels supported
D3D_FEATURE_LEVEL gFeatureLevels[] =
{
	D3D_FEATURE_LEVEL_11_0,
	D3D_FEATURE_LEVEL_10_1,
	D3D_FEATURE_LEVEL_10_0,
	D3D_FEATURE_LEVEL_9_1
};

UINT gNumFeatureLevels = ARRAYSIZE(gFeatureLevels);

static CComPtrCustom<ID3D11Device> lDevice;
static CComPtrCustom<ID3D11DeviceContext> lImmediateContext;
static CComPtrCustom<IDXGIOutputDuplication> lDeskDupl;
static bool didInit = false;

BF_EXPORT bool BF_CALLTYPE Capture_GetFrame(uint8* bits, int x, int y, int width, int height)
{
	DXGI_OUTPUT_DESC lOutputDesc;
	DXGI_OUTDUPL_DESC lOutputDuplDesc;

	if (!didInit)
	{
		didInit = true;

		D3D_FEATURE_LEVEL lFeatureLevel;

		HRESULT hr(E_FAIL);

		// Create device
		for (UINT DriverTypeIndex = 0; DriverTypeIndex < gNumDriverTypes; ++DriverTypeIndex)
		{
			hr = D3D11CreateDevice(
				nullptr,
				gDriverTypes[DriverTypeIndex],
				nullptr,
				0,
				gFeatureLevels,
				gNumFeatureLevels,
				D3D11_SDK_VERSION,
				&lDevice,
				&lFeatureLevel,
				&lImmediateContext);

			if (SUCCEEDED(hr))
			{
				// Device creation success, no need to loop anymore
				break;
			}

			lDevice.Release();

			lImmediateContext.Release();
		}

		if (FAILED(hr))
			return false;

		Sleep(100);

		if (lDevice == nullptr)
			return false;

		// Get DXGI device
		CComPtrCustom<IDXGIDevice> lDxgiDevice;

		hr = lDevice->QueryInterface(IID_PPV_ARGS(&lDxgiDevice));

		if (FAILED(hr))
			return false;

		// Get DXGI adapter
		CComPtrCustom<IDXGIAdapter> lDxgiAdapter;
		hr = lDxgiDevice->GetParent(
			__uuidof(IDXGIAdapter),
			reinterpret_cast<void**>(&lDxgiAdapter));

		if (FAILED(hr))
			return false;

		lDxgiDevice.Release();

		UINT Output = 0;

		// Get output
		CComPtrCustom<IDXGIOutput> lDxgiOutput;
		hr = lDxgiAdapter->EnumOutputs(
			Output,
			&lDxgiOutput);

		if (FAILED(hr))
			return false;

		lDxgiAdapter.Release();

		hr = lDxgiOutput->GetDesc(
			&lOutputDesc);

		if (FAILED(hr))
			return false;

		// QI for Output 1
		CComPtrCustom<IDXGIOutput1> lDxgiOutput1;

		hr = lDxgiOutput->QueryInterface(IID_PPV_ARGS(&lDxgiOutput1));

		if (FAILED(hr))
			return false;

		lDxgiOutput.Release();

		// Create desktop duplication
		hr = lDxgiOutput1->DuplicateOutput(
			lDevice,
			&lDeskDupl);

		if (FAILED(hr))
			return false;

		lDxgiOutput1.Release();
	}

	//lGDIImage.Release();

	// Create GUI drawing texture
	lDeskDupl->GetDesc(&lOutputDuplDesc);

	D3D11_TEXTURE2D_DESC desc;

	desc.Width = width;
	desc.Height = height;
	desc.Format = lOutputDuplDesc.ModeDesc.Format;
	desc.ArraySize = 1;
	desc.BindFlags = D3D11_BIND_FLAG::D3D11_BIND_RENDER_TARGET;
	desc.MiscFlags = D3D11_RESOURCE_MISC_GDI_COMPATIBLE;
	desc.SampleDesc.Count = 1;
	desc.SampleDesc.Quality = 0;
	desc.MipLevels = 1;
	desc.CPUAccessFlags = 0;
	desc.Usage = D3D11_USAGE_DEFAULT;
	desc.Width = lOutputDuplDesc.ModeDesc.Width;
	desc.Height = lOutputDuplDesc.ModeDesc.Height;
	desc.Format = lOutputDuplDesc.ModeDesc.Format;
	desc.ArraySize = 1;
	desc.BindFlags = 0;
	desc.MiscFlags = 0;
	desc.SampleDesc.Count = 1;
	desc.SampleDesc.Quality = 0;
	desc.MipLevels = 1;

	desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ | D3D11_CPU_ACCESS_WRITE;
	desc.Usage = D3D11_USAGE_STAGING;

	CComPtrCustom<ID3D11Texture2D> lDestImage;
	auto hr = lDevice->CreateTexture2D(&desc, NULL, &lDestImage);

	if (FAILED(hr))
		return false;

	if (lDestImage == nullptr)
		return false;

	CComPtrCustom<IDXGIResource> lDesktopResource;
	DXGI_OUTDUPL_FRAME_INFO lFrameInfo;

	int lTryCount = 4;

	do
	{
		Sleep(100);

		// Get new frame
		hr = lDeskDupl->AcquireNextFrame(
			250,
			&lFrameInfo,
			&lDesktopResource);

		if (SUCCEEDED(hr))
			break;

		//OutputDebugStrF()

		if (hr == DXGI_ERROR_WAIT_TIMEOUT)
		{
			continue;
		}
		else if (FAILED(hr))
			break;

	} while (--lTryCount > 0);

	if (FAILED(hr))
		return false;
	
	CComPtrCustom<ID3D11Texture2D> lAcquiredDesktopImage;
	hr = lDesktopResource->QueryInterface(IID_PPV_ARGS(&lAcquiredDesktopImage));

	if (FAILED(hr))
		return false;
	
	if (lAcquiredDesktopImage == nullptr)
		return false;

	D3D11_BOX box = { 0 };
	box.left = x;
	box.right = x + width;
	box.top = y;
	box.bottom = y + height;
	box.back = 1;
	lImmediateContext->CopySubresourceRegion(lDestImage, 0, 0, 0, 0, lAcquiredDesktopImage, 0, &box);

	D3D11_MAPPED_SUBRESOURCE resource;
	UINT subresource = D3D11CalcSubresource(0, 0, 0);
	lImmediateContext->Map(lDestImage, subresource, D3D11_MAP_READ_WRITE, 0, &resource);

	for (int y = 0; y < height; y++)
	{
		uint8* src = (uint8*)resource.pData + resource.RowPitch * (height - y - 1);
		uint8* dest = (uint8*)bits + y * width * 4;
		//memcpy(dest, src, width * 4);

		for (int i = 0; i < width; i++)
		{
			dest[0] = src[2];
			dest[1] = src[1];
			dest[2] = src[0];
			dest[3] = src[3];
			dest += 4;
			src += 4;
		}
		
	}
	
	lImmediateContext->Unmap(lDestImage, 0);
	lAcquiredDesktopImage.Release();
	lDeskDupl->ReleaseFrame();
	
	return true;
}

static TLSingleton<String> gCapture_TLStrReturn;

BF_EXPORT __declspec(dllexport) StringView BF_CALLTYPE Capture_GetFrameJPEG(int x, int y, int width, int height, int quality)
{	
	String& outString = *gCapture_TLStrReturn.Get();
	outString.Clear();

	uint8* data = new uint8[width * height * 4];
	if (!Capture_GetFrame(data, x, y, width, height))
	{
		delete data;
		return outString;
	}
	
	JPEGData jpegData;
	jpegData.mBits = (uint32*)data;
	jpegData.mWidth = width;
	jpegData.mHeight = height;
	jpegData.Compress(quality);
	jpegData.mBits = NULL;	
	outString.Insert(0, (char*)jpegData.mSrcData, jpegData.mSrcDataLen);	

	delete data;

	return outString;
}
